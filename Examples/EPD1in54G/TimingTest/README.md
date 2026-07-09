# EPD1in54G Timing Test

This example measures the major operations of the 1.54-inch four-color e-Paper
panel: standard initialization, fast initialization, streaming image data,
display refresh, and sleep.

`refreshDisplay()` sends `0x12, 0x00` and waits for BUSY to become high. The
driver follows Waveshare's reference wait helper, including its initial 100 ms
delay before polling BUSY.

The image data is generated one row at a time. The example does not allocate a
full 10000-byte frame buffer.
