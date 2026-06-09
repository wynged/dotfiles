#!/usr/bin/env bash
# AMD GPU utilization for polybar's custom/script gpu module.
#
# Reads the amdgpu driver's gpu_busy_percent counter from sysfs. We locate the
# card by DRIVER=amdgpu rather than hard-coding card1, because the DRM card
# number can shift across boots. Output is padded to 2 columns to match the
# CPU/memory modules (which use %percentage:2%%).

card=$(grep -lx 'DRIVER=amdgpu' /sys/class/drm/card*/device/uevent 2>/dev/null | head -1)
if [ -z "$card" ]; then
  echo "n/a"
  exit 0
fi

busy=$(cat "${card%/uevent}/gpu_busy_percent" 2>/dev/null)
printf '%2s%%\n' "${busy:-0}"
