# VisualSynth: A Sketch-Based Music Synthesis Tool

This repository contains the source code for the sketch-based music synthesis tool developed for my master's thesis: *"From Perception to Action: Translating Audiovisual Crossmodal Correspondences into a Sketch-Based Music Synthesis Tool"*.

## Overview

VisualSynth allows users to draw shapes on a digital canvas, which are then automatically translated into music in real time. The system maps four visual shape features to four auditory parameters based on empirically established crossmodal correspondences.

## Requirements

- Processing with OSCP5 library
- Sonic Pi

## Setup

1. Install Processing from [processing.org](https://processing.org)
2. Install OSCP5 library in Processing: Sketch → Import Library → Add Library → search "OSCP5"
3. Install Sonic Pi from [sonic-pi.net](https://sonic-pi.net)
4. Configure sample path on line 12 to point to your instrument samples folder
5. Run Sonic Pi, then run the Processing sketch

## How It Works
1. Draw a shape on the Processing canvas
2. Shape analysis extracts shape metrics
3. Translation converts the shape metrics to sound metrics
4. OSC communication sends sound values to Sonic Pi
5. Sound synthesis selects an instrument and melody pattern, then plays the sound
