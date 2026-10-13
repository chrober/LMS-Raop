use strict;
use warnings;
use Test::More;

my $source = $ENV{RAOPBRIDGE_SQUEEZE2RAOP_SOURCE}
	|| 'application/squeeze2raop/squeeze2raop.c';

open my $fh, '<', $source or die "cannot read $source: $!";
local $/;
my $content = <$fh>;
close $fh;

unlike($content, qr/ResumePreroll|resume_preroll/,
	'the retired RTP-timeline setting cannot alter native resume behavior');

like($content, qr/if \(jiffies\)\s*\n\s*raopcl_start_at\(device->Raop,/,
	'the sole native resume path retains LMS-provided timing when present');

done_testing;
