# Godot 4 FFT Ocean

This is essentially a combination of [Acerola](https://github.com/GarrettGunnell/Water), [Jump Trajectory](https://github.com/gasgiant/FFT-Ocean), and [tessarakkt](https://github.com/tessarakkt/godot4-oceanfft/tree/devel)'s implementations of Ocean waves using Fast Fourier Transforms on oceanographic spectra. My implementation uses a JONSWAP spectrum that allows for bias towards ocean swell, which is then converted to the time domain and uses FFTs with precomputed indices and twiddle values to generate a displacement and normal map for vertex and lighting adjustment. Foam accumulation is handled using jacobian values which are calculated after each FFT. 

This was developed in Godot 4.2, which uses their compute shader pipeline leveraging custom GLSL shaders. Texture2DRDs are utilized via Godot 4.2 and allow faster access to textures from both custom compute shaders for modification and the native gdhsader language for vertex and fragment portions. This implementation performs with a steady 60 FPS when simulating a 1024x1024 map (~1 million waves), and 30 FPS when simulating a 2048x2048 map (~4.2 million waves). 

Below are all of the resources I consulted during the development process-- the most used were the three repositories linked above as well as "Realtime GPGPU FFT Ocean Water Simulation" by Fynn-Jorin Flügge and "Simulating Ocean Water" by Jerry Tessendorf.

### References:

JONSWAP/Ocean Spectra:

https://wikiwaves.org/Ocean-Wave_Spectra

https://www.codecogs.com/library/engineering/fluid_mechanics/waves/spectra/jonswap.php

https://archimer.ifremer.fr/doc/00091/20226/17877.pdf

https://www.youtube.com/watch?v=ApxvmR-zn1Y&ab_channel=nptelhrd

https://www.youtube.com/watch?v=FxSNEUhLThs&ab_channel=nptelhrd

Code Examples:

https://github.com/godotengine/godot-demo-projects/tree/master/misc/compute_shader_heightmap

https://github.com/tessarakkt/godot4-oceanfft/tree/devel

https://github.com/gasgiant/FFT-Ocean

https://github.com/GarrettGunnell/Water

Holistic Tutorials:

https://web.archive.org/web/20230204062542/http://www.keithlantz.net/2011/10/ocean-simulation-part-one-using-the-discrete-fourier-transform/

https://web.archive.org/web/20230309153757/https://www.keithlantz.net/2011/11/ocean-simulation-part-two-using-the-fast-fourier-transform/

https://www.gamedev.net/forums/topic/666713-explaining-to-an-idiot-me-about-mathematics-concerning-ocean-waves/

https://github.com/GarrettGunnell/Water

https://www.slideshare.net/Codemotion/an-introduction-to-realistic-ocean-rendering-through-fft-fabio-suriano-codemotion-rome-2017

https://www.youtube.com/watch?v=ClW3fo94KR4&t=0s&ab_channel=Codemotion

Professional Papers:

[Realtime GPGPU FFT Ocean Water Simulation](https://tore.tuhh.de/bitstream/11420/1439/1/GPGPU_FFT_Ocean_Simulation.pdf)

https://people.computing.clemson.edu/~jtessen/reports/papers_files/coursenotes2004.pdf

[Ocean Surface Generation and Rendering](https://www.cg.tuwien.ac.at/research/publications/2018/GAMPER-2018-OSG/GAMPER-2018-OSG-thesis.pdf)

Examples in Games:

[The Technical Art of SoT](https://www.youtube.com/watch?v=y9BOz2dFZzs)

https://gpuopen.com/gdc-presentations/2019/gdc-2019-agtd6-interactive-water-simulation-in-atlas.pdf

https://www.youtube.com/watch?v=Dqld965-Vv0&ab_channel=GDC

FFT:

https://www.youtube.com/watch?v=iTMn0Kt18tg&ab_channel=MITOpenCourseWare

https://www.youtube.com/watch?v=1mVbZLHLaf0&list=PLuh62Q4Sv7BUSzx5Jr8Wrxxn-U10qG1et&index=13&ab_channel=RichRadke

https://tore.tuhh.de/bitstream/11420/1439/1/GPGPU_FFT_Ocean_Simulation.pdf
