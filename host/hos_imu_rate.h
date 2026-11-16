/* (fork) The ROG Ally's IMU (Bosch, ACPI\BOSC0200) through the Windows sensor API: SDL3 fuses it into the built-in pad, but it
   never sets a report interval or a change sensitivity, so Windows sends a new reading only when the value moves past the
   driver's threshold, at its default rate: the gyroscope read the same values for over a second at rest (Hookshot turned it
   off and on every few seconds) and slow aiming moved in steps. This opens the gyrometer and the accelerometer as a client of
   its own, asks for their shortest report interval and no change threshold (the sensor stack serves every client the most
   demanding settings asked), and holds them open with an event sink for the run. Windows only; C, no libraries beyond ole32. */
#pragma once
#ifdef __cplusplus
extern "C" {
#endif
/* Starts once (later calls do nothing); stats: readings seen by this client since the start (gyro, accel), may be NULL */
int hos_imu_rate_start(void);
void hos_imu_rate_stats(long *gyro, long *accel, unsigned *interval_ms);
/* whether the device has a gyroscope of its own (found by the start): its readings stop at rest, as the driver sends none */
int hos_imu_rate_has_gyro(void);
#ifdef __cplusplus
}
#endif
