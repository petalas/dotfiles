#!/usr/bin/env bash

install_gradle_operations() {
    sdkman_candidate_operations gradle Gradle
}

install_gradle() {
    install_sdkman_candidate gradle gradle Gradle
}
