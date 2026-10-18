use strict;
use warnings;
use Test::More;

my $file = 'plugin/Plugin.pm';
open my $fh, '<', $file or die "Cannot read $file: $!";
my $source = do { local $/; <$fh> };
close $fh;

like(
	$source,
	qr/Slim::Control::Request::subscribe\(\\&resumeSeekRecovery, \[\['pause', 'stop'\]\]\);/,
	'Resume recovery subscribes to the pause and stop root commands',
);

unlike(
	$source,
	qr/\[\['pause', 'play', 'stop', 'mode'\]\]/,
	'Does not declare root commands as one invalid command hierarchy',
);

like(
	$source,
	qr/Time::HiRes::time\(\) \+ 0\.05.*?Slim::Player::Source::gototime\(\$client, \$position\)/s,
	'Rebuilds the captured position shortly after LMS resumes playback',
);

like(
	$source,
	qr/Time::HiRes::time\(\) \+ 0\.05, sub \{\s*return unless Slim::Player::Source::playmode\(\$client\) eq 'play';\s*my \(\$current_source\) = resumeSeekRecoverySource\(\$client\);\s*return unless \$resumeRecovery->same_source\(\$source, \$current_source\);.*?Slim::Player::Source::gototime\(\$client, \$position\)/s,
	'Rechecks the playing source before the deferred rebuild can seek',
);

like(
	$source,
	qr/Time::HiRes::time\(\) \+ 1\.25.*?\$client->volume\(\$volume\)/s,
	'Reapplies the configured player volume after the rebuilt stream starts',
);

done_testing;
