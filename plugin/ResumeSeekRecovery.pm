package Plugins::RaopBridge::ResumeSeekRecovery;

use strict;
use warnings;

sub new {
	return bless { paused_positions => {} }, shift;
}

sub device_entries {
	my ($self, $devices) = @_;
	return () unless defined $devices;
	return @{$devices} if ref $devices eq 'ARRAY';
	return ($devices) if ref $devices eq 'HASH' && exists $devices->{mac};
	return values %{$devices} if ref $devices eq 'HASH';
	return ();
}

sub same_source {
	my ($self, $expected, $actual) = @_;
	return defined $expected && defined $actual && $expected eq $actual;
}

sub request_observed_message {
	my ($self, $player_name, $request, $mode, $enabled) = @_;
	return sprintf(
		'Resume recovery for %s: observed %s in %s mode; setting %s',
		$player_name,
		$request,
		$mode,
		$enabled ? 'enabled' : 'disabled',
	);
}

sub pause_capture_message {
	my ($self, $player_name, $position) = @_;
	return sprintf('Resume recovery for %s: captured pause position %.3fs', $player_name, $position);
}

sub pre_rebuild_message {
	my ($self, $player_name, $current_position, $target_position) = @_;
	return sprintf(
		'Resume recovery for %s: Lyrion position before rebuild %.3fs; seeking to %.3fs',
		$player_name,
		$current_position,
		$target_position,
	);
}

sub rebuild_checkpoint_message {
	my ($self, $player_name, $target_position, $elapsed, $current_position) = @_;
	return sprintf(
		'Resume recovery for %s: rebuild checkpoint after %.2fs reports Lyrion position %.3fs (target %.3fs)',
		$player_name,
		$elapsed,
		$current_position,
		$target_position,
	);
}

sub remember_pause {
	my ($self, $player_id, $source_id, $position, $seekable, $enabled) = @_;
	return if !$enabled || !$seekable || !defined $source_id || !defined $position || $position < 0;
	$self->{paused_positions}{$player_id} = {
		source_id => $source_id,
		position  => $position,
	};
	return 1;
}

sub take_resume_position {
	my ($self, $player_id, $source_id, $seekable) = @_;
	my $recovery = delete $self->{paused_positions}{$player_id};
	return if !$seekable || !defined $recovery || $recovery->{source_id} ne $source_id;

	return $recovery->{position};
}

sub clear {
	my ($self, $player_id) = @_;
	delete $self->{paused_positions}{$player_id};
}

1;
