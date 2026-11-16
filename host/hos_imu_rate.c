/* (fork) see hos_imu_rate.h */
#if defined(_WIN32) && (defined(__MINGW32__) || defined(_MSC_VER))
#define COBJMACROS
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <objbase.h>
#include <propvarutil.h>
#include <sensorsapi.h>
#include <sensors.h>
#include <portabledevicetypes.h>
#include <stdio.h>
void hos_log(const char *fmt, ...);   /* (hos.h) */
#include "hos_imu_rate.h"

/* (the GUIDs and keys used, defined here: nothing to link beyond ole32) */
static const GUID kClsidSensorManager = {0x77A1C827, 0xFCD2, 0x4689, {0x89, 0x15, 0x9D, 0x61, 0x3C, 0xC5, 0xFA, 0x3E}};
static const GUID kIidSensorManager = {0xBD77DB67, 0x45A8, 0x42DC, {0x8D, 0x00, 0x6D, 0xCF, 0x15, 0xF8, 0x37, 0x7A}};
static const GUID kIidSensorEvents = {0x5D8DCC91, 0x4641, 0x47E7, {0xB7, 0xC3, 0xB7, 0x4F, 0x48, 0xA6, 0xC3, 0x91}};
static const GUID kTypeGyro = {0x09485F5A, 0x759E, 0x42C2, {0xBD, 0x4B, 0xA3, 0x49, 0xB7, 0x5C, 0x86, 0x43}};
static const GUID kTypeAccel = {0xC2FB0F5F, 0xE2D2, 0x4C78, {0xBC, 0xD0, 0x35, 0x2A, 0x95, 0x82, 0x81, 0x9D}};
static const GUID kClsidPdValues = {0x0C15D503, 0xD017, 0x47CE, {0x90, 0x16, 0x7B, 0x3F, 0x97, 0x87, 0x21, 0xCC}};
static const GUID kIidPdValues = {0x6848F6F2, 0x3155, 0x4F86, {0xB6, 0xF5, 0x26, 0x3E, 0xEE, 0xAB, 0x31, 0x43}};
#define SENSOR_PROPS_FMTID {0x7F8383EC, 0xD3EC, 0x495C, {0xA8, 0xCF, 0xB8, 0xBB, 0xE8, 0x5C, 0x29, 0x20}}
static const PROPERTYKEY kMinInterval = {SENSOR_PROPS_FMTID, 12};
static const PROPERTYKEY kCurInterval = {SENSOR_PROPS_FMTID, 13};
static const PROPERTYKEY kSensitivity = {SENSOR_PROPS_FMTID, 14};
#define MOTION_FMTID {0x3F8A69A2, 0x07C5, 0x4E48, {0xA9, 0x65, 0xCD, 0x79, 0x7A, 0xAB, 0x56, 0xD5}}
static const GUID kIidUnknown = {0x00000000, 0x0000, 0x0000, {0xC0, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x46}};

static volatile LONG seen_gyro, seen_accel, started;
static unsigned interval_used;
static volatile LONG have_gyro;

/* ---- an ISensorEvents that only counts (held for the run: what keeps this client's settings in force) ---- */
typedef struct Sink { ISensorEventsVtbl *lpVtbl; LONG refs; volatile LONG *count; } Sink;
static HRESULT STDMETHODCALLTYPE sk_qi(ISensorEvents *t, REFIID iid, void **out) {
    if (IsEqualIID(iid, &kIidUnknown) || IsEqualIID(iid, &kIidSensorEvents)) { *out = t; ISensorEvents_AddRef(t); return S_OK; }
    *out = NULL;
    return E_NOINTERFACE;
}
static ULONG STDMETHODCALLTYPE sk_addref(ISensorEvents *t) { return InterlockedIncrement(&((Sink *)t)->refs); }
static ULONG STDMETHODCALLTYPE sk_release(ISensorEvents *t) { return InterlockedDecrement(&((Sink *)t)->refs); }   /* (static) */
static HRESULT STDMETHODCALLTYPE sk_state(ISensorEvents *t, ISensor *s, SensorState st) { (void)t, (void)s, (void)st; return S_OK; }
static HRESULT STDMETHODCALLTYPE sk_data(ISensorEvents *t, ISensor *s, ISensorDataReport *r) {
    (void)s, (void)r;
    InterlockedIncrement(((Sink *)t)->count);
    return S_OK;
}
static HRESULT STDMETHODCALLTYPE sk_event(ISensorEvents *t, ISensor *s, REFGUID id, IPortableDeviceValues *d) {
    (void)t, (void)s, (void)id, (void)d;
    return S_OK;
}
static HRESULT STDMETHODCALLTYPE sk_leave(ISensorEvents *t, REFSENSOR_ID id) { (void)t, (void)id; return S_OK; }
static ISensorEventsVtbl sink_vtbl = {sk_qi, sk_addref, sk_release, sk_state, sk_data, sk_event, sk_leave};
static Sink sink_gyro = {&sink_vtbl, 1, &seen_gyro}, sink_accel = {&sink_vtbl, 1, &seen_accel};

/* the shortest interval and no threshold on the three axes; returns the interval set (0: none) */
static unsigned tune(ISensor *s, const PROPERTYKEY *axes) {
    unsigned ms = 0;
    PROPVARIANT v;
    PropVariantInit(&v);
    if (SUCCEEDED(ISensor_GetProperty(s, &kMinInterval, &v)) && v.vt == VT_UI4) ms = v.ulVal;
    PropVariantClear(&v);
    if (!ms) ms = 10;
    IPortableDeviceValues *want = NULL, *sens = NULL, *got = NULL;
    if (FAILED(CoCreateInstance(&kClsidPdValues, NULL, CLSCTX_INPROC_SERVER, &kIidPdValues, (void **)&want))) return 0;
    IPortableDeviceValues_SetUnsignedIntegerValue(want, &kCurInterval, ms);
    if (SUCCEEDED(CoCreateInstance(&kClsidPdValues, NULL, CLSCTX_INPROC_SERVER, &kIidPdValues, (void **)&sens))) {
        PROPVARIANT zero;   /* (each axis' threshold, a double as the sensor drivers read it: none) */
        PropVariantInit(&zero);
        zero.vt = VT_R8;
        zero.dblVal = 0.0;
        for (int i = 0; i < 3; i++) IPortableDeviceValues_SetValue(sens, &axes[i], &zero);
        IPortableDeviceValues_SetIPortableDeviceValuesValue(want, &kSensitivity, sens);
    }
    HRESULT hr = ISensor_SetProperties(s, want, &got);
    if (got) IPortableDeviceValues_Release(got);
    if (sens) IPortableDeviceValues_Release(sens);
    IPortableDeviceValues_Release(want);
    return SUCCEEDED(hr) ? ms : 0;
}

static ISensor *open_one(ISensorManager *m, const GUID *type, Sink *sink, const PROPERTYKEY *axes, unsigned *ms) {
    ISensorCollection *c = NULL;
    ISensor *s = NULL;
    ULONG n = 0;
    if (FAILED(ISensorManager_GetSensorsByType(m, type, &c)) || !c) return NULL;
    if (SUCCEEDED(ISensorCollection_GetCount(c, &n)) && n && SUCCEEDED(ISensorCollection_GetAt(c, 0, &s)) && s) {
        *ms = tune(s, axes);
        ISensor_SetEventSink(s, (ISensorEvents *)sink);
    }
    ISensorCollection_Release(c);
    return s;
}

static DWORD WINAPI imu_main(LPVOID unused) {
    (void)unused;
    if (FAILED(CoInitializeEx(NULL, COINIT_MULTITHREADED))) return 1;
    ISensorManager *m = NULL;
    if (FAILED(CoCreateInstance(&kClsidSensorManager, NULL, CLSCTX_INPROC_SERVER, &kIidSensorManager, (void **)&m)) || !m) {
        CoUninitialize();
        return 1;
    }
    static const PROPERTYKEY gyro_axes[3] = {{MOTION_FMTID, 10}, {MOTION_FMTID, 11}, {MOTION_FMTID, 12}};
    static const PROPERTYKEY accel_axes[3] = {{MOTION_FMTID, 2}, {MOTION_FMTID, 3}, {MOTION_FMTID, 4}};
    unsigned gms = 0, ams = 0;
    ISensor *g = open_one(m, &kTypeGyro, &sink_gyro, gyro_axes, &gms);
    ISensor *a = open_one(m, &kTypeAccel, &sink_accel, accel_axes, &ams);
    interval_used = gms ? gms : ams;
    hos_log("hid: (fork) the device's own motion sensors: gyroscope %s, accelerometer %s, asked for readings every %u ms with no "
            "threshold (what SDL's fused pad reads)", g ? "found" : "none", a ? "found" : "none", interval_used);
    have_gyro = g != NULL;
    for (;;) Sleep(INFINITE);   /* (held for the run, with the manager: this thread stays in COM and sleeps) */
    return 0;
}

int hos_imu_rate_start(void) {
    if (InterlockedExchange(&started, 1)) return 1;
    HANDLE t = CreateThread(NULL, 0, imu_main, NULL, 0, NULL);
    if (!t) return 0;
    CloseHandle(t);
    return 1;
}

int hos_imu_rate_has_gyro(void) { return have_gyro != 0; }
void hos_imu_rate_stats(long *gyro, long *accel, unsigned *interval_ms) {
    if (gyro) *gyro = seen_gyro;
    if (accel) *accel = seen_accel;
    if (interval_ms) *interval_ms = interval_used;
}
#else
int hos_imu_rate_start(void) { return 0; }
int hos_imu_rate_has_gyro(void) { return 0; }
void hos_imu_rate_stats(long *gyro, long *accel, unsigned *interval_ms) {
    if (gyro) *gyro = 0;
    if (accel) *accel = 0;
    if (interval_ms) *interval_ms = 0;
}
#endif
