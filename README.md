# cs7323_lab4

In this lab you will create an iOS application that uses the Vision framework to perform some kind of detection (such as facial landmarks, hand, or body pose). You can choose to use the example code from class as a starting point for the application. There is a lot of free rein in this assignment to choose different functionality. 

 -  Reads and displays images from the camera in real time
 -  Perform detection using apple vision of one of the following: (1) face, (2) hands, or (3) human body 
 -  Highlights a bounding box around the detected object using CGPath Overlays and Core Animation Transactions. 
 -  For the detected object, you should use features of the object (such as facial landmark positions, body joint positions, or hand joint positions) to detect something about the object not currently automatically detected by the Vision API. 
   -  As an example, you might use the DetectHumanHandPoseRequest to detect rock, paper, scissors, and "no action" for the hand.  This is only and example--you are not required to perform this classification. 
   -  You are NOT required to use machine learning for this detection. That is, your method can employ deterministic algorithms or heuristics. For instance, you might detect "scissors" by looking at the normalized distance between the index and middle fingers. 
   -  Be sure to look at the Vision API, as many human body poses, hand positions, and facial poses are already detected automatically. Your detection should support something new that is not part of the existing API.
   -  Your detected feature of the object should result in a substantial UI change in the app. For example, if detecting rock. paper, and scissors, you might show an image when detected and create a CPU player that can play against you. Then track who won.  
 -  5000 Level Students: you are free to provide extra functionality for credit towards exceptional portion of rubric.
 -  Exceptional work (required for 7000 level students): display CGPath Overlays using Core Animation for the landmarks detected (or hand or body joints). Change the color of these joints or landmarks when they trigger a detection from your method. For example, if performing scissors, paper, rock, your app might change the index and middle finger tips points to be red when they are in close enough proximity to be "scissors" and yellow otherwise. 

Turn in:

1. The source code for your app in zipped format or GitHub Link. Use proper coding techniques and naming conventions for objective C, C++ and swift. DO NOT include the OpenCVFramework directory (bundle) in your submission. 
2. Your team member names and team name as a text file. 
3. A video of your app working as intended. 
