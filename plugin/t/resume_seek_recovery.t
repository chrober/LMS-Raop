use strict;
use warnings;
use Test::More;
use lib $ENV{'RAOPBRIDGE_PLUGIN_ROOT'} || 'plugin';
require 'ResumeSeekRecovery.pm';

my $recovery = Plugins::RaopBridge::ResumeSeekRecovery->new;

is_deeply(
	[ $recovery->device_entries([{ mac => 'a' }, { mac => 'b' }]) ],
	[{ mac => 'a' }, { mac => 'b' }],
	'keeps an array of XML device entries',
);
is_deeply(
	[ $recovery->device_entries({ mac => 'a' }) ],
	[{ mac => 'a' }],
	'normalizes a single XML device entry to one array member',
);
is_deeply(
	[ sort { $a->{mac} cmp $b->{mac} } $recovery->device_entries({ kitchen => { mac => 'b' }, living_room => { mac => 'a' } }) ],
	[{ mac => 'a' }, { mac => 'b' }],
	'normalizes an XML device map keyed by player name',
);
is_deeply([ $recovery->device_entries(undef) ], [], 'normalizes a missing XML device list');
ok($recovery->same_source('file:///music/example.flac', 'file:///music/example.flac'), 'recognizes the same source for deferred recovery work');
ok(!$recovery->same_source('file:///music/example.flac', 'file:///music/next.flac'), 'does not apply deferred recovery work to a new source');
ok(!$recovery->same_source(undef, 'file:///music/example.flac'), 'does not treat an unknown source as matching');

is(
	$recovery->request_observed_message('Küche', 'pause 1', 'pause', 1),
	'Resume recovery for Küche: observed pause 1 in pause mode; setting enabled',
	'renders a callback-boundary diagnostic for pause and resume investigation',
);
is(
	$recovery->pause_capture_message('Küche', 278.79),
	'Resume recovery for Küche: captured pause position 278.790s',
	'renders a timestamp-correlatable pause snapshot diagnostic',
);
is(
	$recovery->pre_rebuild_message('KÃ¼che', 278.912, 278.790),
	'Resume recovery for KÃ¼che: Lyrion position before rebuild 278.912s; seeking to 278.790s',
	'preserves the original pre-rebuild diagnostic format',
);
is(
	$recovery->rebuild_checkpoint_message('KÃ¼che', 278.790, 1.50, 278.790),
	'Resume recovery for KÃ¼che: rebuild checkpoint after 1.50s reports Lyrion position 278.790s (target 278.790s)',
	'preserves the original post-rebuild checkpoint diagnostic format',
);
ok(
	$recovery->remember_pause('aa:aa:26:69:17:61', 'file:///music/example.flac', 123.45, 1, 1),
	'remembers a seekable pause for an enabled player',
);
is(
	$recovery->take_resume_position('aa:aa:26:69:17:61', 'file:///music/example.flac', 1),
	123.45,
	'returns the exact saved position once on resume',
);
ok(!defined $recovery->take_resume_position('aa:aa:26:69:17:61', 'file:///music/example.flac', 1), 'consumes a recovery position after use');

ok($recovery->remember_pause('aa:aa:26:69:17:61', 'file:///music/example.flac', 80.0, 1, 1),
	'allows the later pause notification to refresh the captured position');
ok($recovery->remember_pause('aa:aa:26:69:17:61', 'file:///music/example.flac', 80.1, 1, 1),
	'updates the captured position on a duplicate playlist pause notification');
is(
	$recovery->take_resume_position('aa:aa:26:69:17:61', 'file:///music/example.flac', 1),
	80.1,
	'uses the latest pause position for the deferred post-resume rebuild',
);

ok(
	!$recovery->remember_pause('aa:aa:26:69:17:61', 'http://radio.example/stream', 70, 0, 1),
	'does not arm a non-seekable source',
);
ok(!defined $recovery->take_resume_position('aa:aa:26:69:17:61', 'http://radio.example/stream', 1), 'never recovers a non-seekable source');

ok(
	!$recovery->remember_pause('aa:aa:26:69:17:61', 'file:///music/example.flac', 70, 1, 0),
	'does not arm a disabled player',
);
ok(!defined $recovery->take_resume_position('aa:aa:26:69:17:61', 'file:///music/example.flac', 1), 'never recovers a disabled player');

$recovery->remember_pause('aa:aa:26:69:17:61', 'file:///music/old.flac', 42, 1, 1);
ok(!defined $recovery->take_resume_position('aa:aa:26:69:17:61', 'file:///music/new.flac', 1), 'does not seek a new source after a paused track changed');

$recovery->remember_pause('aa:aa:26:69:17:61', 'file:///music/example.flac', 50, 1, 1);
$recovery->clear('aa:aa:26:69:17:61');
ok(!defined $recovery->take_resume_position('aa:aa:26:69:17:61', 'file:///music/example.flac', 1), 'clears a pending recovery when playback stops');

done_testing;
