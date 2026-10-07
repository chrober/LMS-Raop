#include <assert.h>
#include <stdint.h>
#include <stdio.h>

#include "resume_timing.h"

static uint64_t ntp_milliseconds(uint32_t milliseconds) {
	return ((uint64_t) milliseconds << 32) / 1000;
}

static uint64_t ntp_samples(uint32_t frames, uint32_t sample_rate) {
	return ((uint64_t) frames << 32) / sample_rate;
}

int main(void) {
	const uint64_t now = UINT64_C(0x1234567800000000);
	const uint64_t expected = now + ntp_milliseconds(200) - ntp_samples(99225, 44100);

	assert(raop_resume_preroll_start(now, 99225, 44100) == expected);
	assert(raop_resume_preroll_start(now, 0, 44100) == now + ntp_milliseconds(200));
	puts("resume_timing_test: ok");
	return 0;
}
