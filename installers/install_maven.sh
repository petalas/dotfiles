#!/usr/bin/env bash

install_maven_operations() {
    sdkman_candidate_operations maven Maven
}

install_maven() {
    install_sdkman_candidate maven mvn Maven
}
