# SecondSight
SecondSight is an application that uses an iPhone to detect hazard objects for the visually impaired individuals. It can also perform scene description without hazards. It is not designed to replace any existing tools and methods but to compliment any existing methods.

The applicaiton requires a live camera input for object detection and speech discription using vision lanaguage model. There are two modes:

**WARNING:** This is a prototype for proof of concept ONLY. For health and safetly, practical use is **STRICTLY PROHIBITED**.

## 1. Hazard Detection Mode
When the camera is pointed on the ground within distance of approximately 3 strides. The app will detect 5 common small objects.
- rocks
- bottles
- potholes
- poles
- stairs

Once a hazard object is detected, the iPhone will send notifications to the Apple Watch. The notifications include speech, sounds, and haptic feedback.

User can tap the screen to describe the hazard in more details.

## 2. Scene Description Mode
When the camera is pointed above the ground (30 degrees), the app will stop detection. User can tap the screen to describe the environment in more details.

# Edge AI
Two models are deployed into the device and inference locally. The app does not require internet connection.

The app can be used as a standalone mode without the smart watch. 

If users have a watch, it can be paired with the iPhone to receive notifications via bluetooth.

# Performance
The detection is spontaneous, which is critical for to notify users to take timely action.

The scene description uses the FastVLM model released by Apple Inc. It has a slight delay on first load but faster after to an acceptable speed.

# Installation
Follow Apple's Development Guide for account subscription, app signing, and deployment for iPhone and Apple Watch.