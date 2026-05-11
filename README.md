About the testbench that we used 
### 1. System-Level Integration Test
* **`tb_top_system.v`**
  * **Purpose:** Validates the complete data pipeline from the camera input to the VGA output.
  * **Key Features:**
    * **Camera Spoofing:** Injects simulated pixel data into the pipeline to mimic the OV7670 camera behavior.
    * **Image Generation:** Automatically generates an `output_frame.ppm` file to visually verify the final processed image.
    * **Collision Detection:** Monitors the Dual-Port BRAM to ensure no read/write memory collisions occur across different clock domains (Camera PCLK vs. VGA Clock).
    * **Latency Handling:** Incorporates initialization delays (`simulation_ready` flag) to account for natural system latency and prevent false error reporting during the initial state.

### 2. Unit-Level Testbenches
* **`tb_camera_capture_640x320.v`**
  * **Purpose:** Verifies the camera data acquisition logic.
  * **Key Features:** Tests the proper assembly of RGB565 high/low bytes using the `HREF` signal, and validates the spatial downsampling logic that reduces the raw 640x480 input to a 320x240 resolution. Ensures precise reset behavior via the `VSYNC` signal.

* **`tb_frame_buffer_640x320.v`**
  * **Purpose:** Tests the Dual-Port Block RAM (BRAM) functionality.
  * **Key Features:** Verifies memory initialization (clearing unknown `X` states to `0`), address incrementation, and asynchronous read/write operations across two independent clock domains.

* **`tb_sccb_config.v`**
  * **Purpose:** Validates the SCCB (I2C-compatible) configuration interface.
  * **Key Features:** Checks the precise timing of START, STOP, and ACK conditions required to successfully write configuration registers to the OV7670 camera module.

* **`tb_filters.v`**
  * **Purpose:** Verifies the image processing and color conversion logic.
  * **Key Features:** Performs pixel-level validation of mathematical formulas (e.g., RGB to Grayscale conversion) to ensure absolute color accuracy before the data reaches the display.

* **`tb_vga_display.v`**
  * **Purpose:** Tests the VGA signal generator.
  * **Key Features:** Verifies the accuracy of Horizontal Sync (`HSYNC`), Vertical Sync (`VSYNC`), and blanking intervals. Ensures that pixel coordinates accurately map to the active video area.
