#!/bin/bash
cd "$(dirname "$0")/../../.."
for cls in ClaudeSpeichernUITests ClaudeFelderUITests; do
  for m in $(grep -o 'func test[A-Za-z0-9_]*' LeanHealthTimerUITests/$cls.swift | sed 's/func //'); do
    echo "##### $cls/$m"
    ./Scripts/run-uitests.sh $cls/$m 2>&1
  done
done
echo "##### ALLDONE"
