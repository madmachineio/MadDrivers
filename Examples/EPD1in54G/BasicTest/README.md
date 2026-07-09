# EPD1in54G Basic Test

This example initializes the Waveshare/Good Display 1.54-inch four-color e-Paper
panel, clears it, then streams a 200x200 four-color test pattern one row at a
time.

The example intentionally does not allocate a full 10000-byte frame buffer.
Each row is 50 bytes because the panel stores four 2-bit pixels in one byte.
