package Plugins::RaopBridge::Plugin;

use strict;

use base qw(Slim::Plugin::Base);

use Config;
use File::Spec::Functions;

use Data::Dumper;
use XML::Simple;

use Slim::Utils::Prefs;
use Slim::Utils::Log;
use Slim::Control::Request;
use Slim::Player::Source;
use Slim::Utils::Timers;
use Time::HiRes ();

my $prefs = preferences('plugin.raopbridge');
my $fade_volume;
my $resumeRecovery;

$prefs->init({ 
	autorun => 1, 
	opts => '', 
	debugs => '', 
	logging => 0, 
	bin => undef, 
	configfile => "raopbridge.xml", 
	profilesURL => initProfilesURL(), 
	autosave => 1, 
	eraselog => 0
});

my $log = Slim::Utils::Log->addLogCategory({
	'category'     => 'plugin.raopbridge',
	'defaultLevel' => 'WARN',
	'description'  => Slim::Utils::Strings::string('PLUGIN_RAOPBRIDGE'),
}); 

sub fade_volume {
	my ($client, $fade, $callback, $callbackargs) = @_;
	return $fade_volume->($client, $fade, $callback, $callbackargs) if $fade > 0 || $client->modelName !~ /RaopBridge/;
	return $callback->($callbackargs) if $callback;
}

sub initPlugin {
	my $class = shift;

	$class->SUPER::initPlugin(@_);
	
	# this is hacky but I won't redefine a whole player model just for this	
	require Slim::Player::SqueezePlay;
	$fade_volume = \&Slim::Player::SqueezePlay::fade_volume;
	*Slim::Player::SqueezePlay::fade_volume = \&fade_volume;
	
	*Slim::Utils::Log::raopbridgeLogFile = sub { Plugins::RaopBridge::Squeeze2raop->logFile; };
		
	require Plugins::RaopBridge::Squeeze2raop;	
	require	Plugins::RaopBridge::Pairing;
	require Plugins::RaopBridge::ResumeSeekRecovery;
	$resumeRecovery = Plugins::RaopBridge::ResumeSeekRecovery->new;
	Slim::Control::Request::subscribe(\&resumeSeekRecovery, [['pause', 'stop']]);
	
	if ($prefs->get('autorun')) {
		Plugins::RaopBridge::Squeeze2raop->start;
	}
	
	if (!$::noweb) {
		require Plugins::RaopBridge::Settings;
		Plugins::RaopBridge::Settings->new;
		# there is a bug in LMS where the "content-type" set in handlers is ignored, only extension matters (and is html by default)
		Slim::Web::Pages->addPageFunction("raopbridge-log", \&Plugins::RaopBridge::Squeeze2raop::logHandler);
		Slim::Web::Pages->addPageFunction("raopbridge-config.xml", \&Plugins::RaopBridge::Squeeze2raop::configHandler);
		Slim::Web::Pages->addPageFunction("raopbridge-guide", \&Plugins::RaopBridge::Squeeze2raop::guideHandler);
	}
	
	$log->info(Dumper(Slim::Utils::OSDetect::details()));
	$log->info( "Using INC", Dumper(\@INC) );
}

sub resumeSeekRecovery {
	my ($request) = @_;
	my $client = $request->client || return;
	return unless $client->modelName =~ /RaopBridge/;

	my $enabled = resumeSeekRecoveryEnabled($client);
	my $mode = Slim::Player::Source::playmode($client);
	$log->info($resumeRecovery->request_observed_message(
		$client->name,
		$request->getRequestString,
		$mode,
		$enabled,
	));

	if ($mode eq 'pause') {
		my ($source, $seekable) = resumeSeekRecoverySource($client);
		my $position = Slim::Player::Source::songTime($client);
		if ($resumeRecovery->remember_pause($client->id, $source, $position, $seekable, $enabled)) {
			$log->info($resumeRecovery->pause_capture_message($client->name, $position));
		}
		return;
	}

	if ($mode eq 'stop') {
		$resumeRecovery->clear($client->id);
		return;
	}

	return unless $mode eq 'play';
	my ($source, $seekable) = resumeSeekRecoverySource($client);
	my $position = $resumeRecovery->take_resume_position($client->id, $source, $seekable);
	return unless defined $position;

	$log->info(sprintf('Resume recovery for %s: rebuilding seekable source at %.3fs', $client->name, $position));
	Slim::Utils::Timers::setTimer($resumeRecovery, Time::HiRes::time() + 0.05, sub {
		return unless Slim::Player::Source::playmode($client) eq 'play';
		my ($current_source) = resumeSeekRecoverySource($client);
		return unless $resumeRecovery->same_source($source, $current_source);
		my $before_rebuild = Slim::Player::Source::songTime($client);
		if (defined $before_rebuild) {
			$log->info($resumeRecovery->pre_rebuild_message($client->name, $before_rebuild, $position));
		}
		Slim::Player::Source::gototime($client, $position);
		Slim::Utils::Timers::setTimer($resumeRecovery, Time::HiRes::time() + 1.25, sub {
			return unless Slim::Player::Source::playmode($client) eq 'play';
			my ($current_source) = resumeSeekRecoverySource($client);
			return unless $resumeRecovery->same_source($source, $current_source);
			my $volume = $client->volume;
			$client->volume($volume) if defined $volume;
		});
		Slim::Utils::Timers::setTimer($resumeRecovery, Time::HiRes::time() + 1.50, sub {
			return unless Slim::Player::Source::playmode($client) eq 'play';
			my ($current_source) = resumeSeekRecoverySource($client);
			return unless $resumeRecovery->same_source($source, $current_source);
			my $current_position = Slim::Player::Source::songTime($client);
			return unless defined $current_position;
			$log->info($resumeRecovery->rebuild_checkpoint_message($client->name, $position, 1.50, $current_position));
		});
	});
}

sub resumeSeekRecoverySource {
	my ($client) = @_;
	my $song = $client->playingSong || return;
	my $track = $song->currentTrack || return;

	return ($track->url, $song->canSeek ? 1 : 0);
}

sub resumeSeekRecoveryEnabled {
	my ($client) = @_;
	require Plugins::RaopBridge::Squeeze2raop;
	my $file = Plugins::RaopBridge::Squeeze2raop->configFile;
	return 0 unless -e $file;

	my $config = eval { XMLin($file, ForceArray => ['device'], KeepRoot => 0, NoAttr => 1, SuppressEmpty => 1) };
	return 0 if !$config;

	my $enabled = $config->{common}{resume_seek_recovery} || 0;
	for my $device ($resumeRecovery->device_entries($config->{device})) {
		next unless defined $device->{mac} && lc($device->{mac}) eq lc($client->id);
		$enabled = $device->{resume_seek_recovery} if defined $device->{resume_seek_recovery};
		last;
	}

	return $enabled ? 1 : 0;
}

sub initProfilesURL {
	my $file = catdir(Slim::Utils::PluginManager->allPlugins->{'RaopBridge'}->{'basedir'}, 'install.xml');
	return XMLin($file, ForceArray => 0, KeepRoot => 0, NoAttr => 0)->{'profilesURL'};
}

sub shutdownPlugin {
	if ($prefs->get('autorun')) {
		Plugins::RaopBridge::Squeeze2raop->stop;
	}
}

1;
