/*
 * Squeeze2raop - Squeezelite to Airplay bridge
 */

#pragma once

#include <stdint.h>

/*
 * Start a replacement RTP timeline slightly in the future.  Receivers need
 * enough packets before that instant to fill their playback latency.
 */
uint64_t raop_resume_preroll_start(uint64_t now_ntp, uint32_t latency_frames,
					   uint32_t sample_rate);
