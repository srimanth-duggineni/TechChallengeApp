#!/bin/sh
sleep 5;

# TODO find a way to call updatedb only once
./TechChallengeApp updatedb
./TechChallengeApp serve