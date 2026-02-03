# WebGPU Medical Volume Renderer

A real-time, interactive 3D volume renderer for medical imaging data (NIFTI), built from first principles using the WebGPU API. This project explores advanced visualization techniques by applying computational geometry and calculus directly on the GPU to enhance anatomical structures.

## Demo
---
<p align="center">
   <b>3D slicing along the z axis</b>
  <video src="https://github.com/user-attachments/assets/01d9e08b-032a-4c74-9174-8c9349b452b2" width="80%" controls></video>
  <br>
</p>
<table style="width: 100%;">
  <tr>
    <td style="width: 50%; text-align: center;">
      <img src="https://github.com/user-attachments/assets/aa1e6ffb-a158-4eee-919d-f8ac69b2b218" alt="Demo 1" style="max-width: 100%;">
      <p align="center"><b>Visualising lateral ventricles and deep cerebral venous plexus.</b></p>
    </td>
    <td style="width: 50%; text-align: center;">
      <img src="https://github.com/user-attachments/assets/ad6bb66c-2823-479d-8047-a77d423e5118" alt="Demo 2" style="max-width: 100%;">
      <p align="center"><b>Transverse section showing the optic chiasm and pathway.</b></p>
    </td>
  </tr>
</table>

## About The Project

This project was born from a desire to bridge the gap between clinical medicine and cutting-edge computer graphics. As a medical student, I found that standard 2D slice-by-slice viewing of MRI scans was often insufficient for understanding complex 3D anatomical relationships.

This renderer is my solution: a high-performance, web-native tool that provides an intuitive, interactive way to explore volumetric medical data. It moves beyond simple visualization to perform real-time analysis, using the power of the GPU to reveal details that might be missed in a traditional viewer.

The entire rendering pipeline is built from scratch, demonstrating a fundamental understanding of modern GPU architecture, 3D mathematics, and shader programming.

## Key Features

-   **Real-Time Volume Ray-Marching:** Implements a custom ray-marching algorithm in a WGSL shader to render volumetric data interactively in the browser.
-   **First-Principles WebGPU Engine:** Built directly on the WebGPU API without relying on third-party libraries for the core rendering logic. This includes a custom render pipeline manager and resource handling.
-   **Advanced Geometric Analysis:** Performs on-the-fly analysis of the volume data directly on the GPU.
    -   **Gradient-Based Edge Detection:** Uses the first derivative (gradient) to highlight boundaries between different tissue types.
    -   **Hessian-Based Curvature Analysis:** Uses the second derivative (Hessian) to distinguish between different shapes (e.g., planes, tubes, spheres), allowing for more sophisticated tissue classification and visualization.
-   **Interactive Transfer Function:** A GUI allows for real-time control over the opacity and color mapping of different tissues, enabling dynamic exploration of the data.
-   **NIFTI File Support:** Includes Python scripts and JavaScript helpers to parse, process, and load data from the NIFTI file format, a standard in medical imaging research.

## 🧠 Deep Learning Integration: Automated Skull-Stripping

To enhance the diagnostic utility of the renderer, I engineered a deep learning pipeline to automatically isolate brain tissue from non-brain anatomy (skull, eyes, background).

### The Architecture
*   **Model:** Custom U-Net Convolutional Neural Network (CNN).
*   **Training:** Built in TensorFlow/Keras, utilizing a **Curriculum Learning** strategy. The model was first pre-trained on 2D Sobel edge maps to learn structural gradients, then fine-tuned on full 3D volumetric data for spatial coherence.
*   **Data:** Proprietary "Golden Set" manually segmented using ITK-SNAP to ensure high-fidelity ground truth.

### Performance & Accuracy
The custom U-Net model demonstrates robust segmentation capabilities, achieving **97% accuracy** on the validation dataset. This high-fidelity segmentation allows for precise isolation of the brain tissue, serving as a reliable ground truth for the visualization engine.
<table style="width: 100%;">
  <tr>
    <td style="width: 50%; text-align: center;">
      <img width="800" height="400" alt="slice_330_original_vs_predicted" src="https://github.com/user-attachments/assets/74bf65a6-741f-42f2-8f44-8fd85d88f758" />
      <p align="center"><b>Edge detection using sobel filter.</b></p>
    </td>
    <td style="width: 50%; text-align: center;">
     <img width="1000" height="500" alt="slice_330_original_with_processed_mask" src="https://github.com/user-attachments/assets/d708be1e-b249-4dff-bc70-c54569f0aba9" />
      <p align="center"><b>Full brain tissue mask result from fine tuning.</b></p>
    </td>
  </tr>
</table>

**Note:** The repository currently reflects the integration of the pre-trained model into the visualization engine. The source code for the model architecture and training pipeline is being refactored and will be uploaded shortly.

## Vision: Towards a Digital Twin

This project serves as the foundational rendering engine for a much larger goal: creating a true "digital twin" of human anatomy. The vision is to build comprehensive, interactive models that fuse medical imaging with other biological data to enable:

-   **Surgical Simulation:** Allowing surgeons to plan and rehearse complex procedures.
-   **Biomechanical Modeling:** Simulating tissue behavior under different conditions.
-   **Enhanced Diagnostics:** Providing clinicians with a more intuitive and data-rich view of patient anatomy.

## Technology Stack

-   **Core Rendering:** WebGPU, WGSL (WebGPU Shading Language)
-   **Frontend & Application Logic:** JavaScript (ES6 Modules)
-   **Build Tooling:** Vite
-   **Matrix Math:** wgpu-matrix (or gl-matrix)
-   **GUI:** dat.gui
-   **Data Pre-processing:** Python, NumPy, NiBabel

## Project Structure

The repository is organized to separate the core rendering engine from the application logic and shaders, promoting modularity and clarity.

```
webgpu-mri/
├── public/
│   └── sub-001/            # Contains the NIFTI data assets
├── src/
│   ├── engine/
│   │   ├── engine.js       # Core WebGPU engine setup and state management
│   │   └── renderPipeline.js # Manages the GPU render pipeline and resources
│   ├── shaders/
│   │   └── raytracer.wgsl  # The heart of the project: the volume ray-marching shader
│   ├── utils/
│   │   └── helpers.js      # Utility functions
│   ├── viewer_scripts/
│   │   └── main.py         # Python scripts for NIFTI data pre-processing
│   ├── main.js             # Main application entry point
│   └── style.css           # Application styles
├── README.md
└── package.json
```

## Getting Started

To get a local copy up and running, follow these simple steps.

### Prerequisites

-   Node.js and npm (or yarn) installed.
-   A modern web browser with WebGPU support (e.g., Chrome, Edge, Firefox Nightly).

### Installation & Usage

1.  **Clone the repository:**
    ```sh
    git clone https://github.com/Bahdmanbabzo/webgpu-mri.git
    ```
2.  **Navigate to the project directory:**
    ```sh
    cd webgpu-mri
    ```
3.  **Install NPM packages:**
    ```sh
    npm install
    ```
4.  **Run the development server:**
    ```sh
    npm run dev
    ```
5.  Open your browser and navigate to the local address provided by Vite (usually `http://localhost:5173`).

## License

Distributed under the MIT License. See `LICENSE` for more information.

## About the Author

**Oserebameh Beckley**

-   LinkedIn: [linkedin.com/in/oserebameh-beckley](https://linkedin.com/in/oserebameh-beckley)
-   GitHub: [github.com/Bahdmanbabzo](https://github.com/Bahdmanbabzo)

A 4th-year medical student with a deep passion for applying computer graphics and AI to solve complex problems in healthcare.
