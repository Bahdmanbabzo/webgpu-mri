# WebGPU Medical Volume Renderer

A real-time, interactive 3D volume renderer for medical imaging data (NIFTI), built from first principles using the WebGPU API. This project explores advanced visualization techniques by applying computational geometry and calculus directly on the GPU to enhance anatomical structures.

## Demo
---

https://github.com/user-attachments/assets/01d9e08b-032a-4c74-9174-8c9349b452b2

<img width="664" height="803" alt="Screenshot 2026-01-08 224434" src="https://github.com/user-attachments/assets/aa1e6ffb-a158-4eee-919d-f8ac69b2b218" /><img width="1270" height="933" alt="optic chiasm showing" src="https://github.com/user-attachments/assets/ad6bb66c-2823-479d-8047-a77d423e5118" />



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
