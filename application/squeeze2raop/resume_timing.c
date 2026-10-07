/*
 * Squeeze2raop - Squeezelite to Airplay bridge
 */

#include "resume_timing.h"

#define NTP_FRACTIONAL_UNITS UINT64_C(4294967296)
#define RESUME_PREROLL_MS 200

uint64_t raop_resume_preroll_start(uint64_t now_ntp, uint32_t latency_frames,
					   uint32_t sample_rate) {
	uint64_t preroll = (NTP_FRACTIONAL_UNITS * RESUME_PREROLL_MS) / 1000;
	uint64_t latency = sample_rate ?
		(NTP_FRACTIONAL_UNITS * latency_frames) / sample_rate : 0;

	return now_ntp + preroll - latency;
}
