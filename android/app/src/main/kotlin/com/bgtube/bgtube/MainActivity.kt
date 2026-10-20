package com.bgtube.bgtube

import com.ryanheise.audioservice.AudioServiceActivity

// AudioServiceActivity shares one Flutter engine between the UI and the
// background audio service, so the UI can reattach to running playback
// after the activity is destroyed (e.g. swiped from recents).
class MainActivity : AudioServiceActivity()
