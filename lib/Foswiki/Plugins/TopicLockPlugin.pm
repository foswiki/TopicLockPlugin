# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details, published at
# http://www.gnu.org/copyleft/gpl.html

=pod

---+ package Foswiki::Plugins::TopicLockPlugin

=cut

package Foswiki::Plugins::TopicLockPlugin;

# Always use strict to enforce variable scoping
use strict;

use Foswiki::Func    ();    # The plugins API
use Foswiki::Plugins ();    # For the API version

use constant DEBUG => 0;    # toggle me

our $VERSION           = '$Rev: 5771 $';
our $RELEASE           = '1.1.1';
our $SHORTDESCRIPTION  = 'Adds 1-click function to lock down topics.';
our $NO_PREFS_IN_TOPIC = 1;
our $pluginName        = 'TopicLockPlugin';

sub initPlugin {
    my ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if ( $Foswiki::Plugins::VERSION < 2.0 ) {
        Foswiki::Func::writeWarning( 'Version mismatch between ',
            __PACKAGE__, ' and Plugins.pm' );
        return 0;
    }

    Foswiki::Func::registerTagHandler( 'TOPICLOCK', \&_TOPICLOCK );
    Foswiki::Func::registerRESTHandler( 'toggleLock', \&_toggleLock );

    # Plugin correctly initialized
    return 1;
}

sub _sanatize {
    my $param = $_[0];
    $param =~ s/[^A-Za-z0-9.]//g;
    $param =~ m/^(.*)$/;
    return $1;
}

sub _expandFormat {
    my $theWeb    = $_[0];
    my $theTopic  = $_[1];
    my $theFormat = $_[2];

    $theFormat =~
s/\$url/&Foswiki::Func::getScriptUrl( $pluginName, "toggleLock", "rest", "locktopic" => $theTopic, "lockweb" => $theWeb )/ge;
    $theFormat =~ s/\$percnt/%/g;
    $theFormat =~ s/\$dollar/$1/g;
    $theFormat =~ s/\$n/\n/g;

    $theFormat =
      Foswiki::Func::expandCommonVariables( $theFormat, $theTopic, $theWeb );

    return $theFormat;
}

sub _TOPICLOCK {
    my ( $session, $params, $theTopic, $theWeb ) = @_;

    my $web          = $params->{web}          || $theWeb;
    my $topic        = $params->{topic}        || $theTopic;
    my $lockformat   = $params->{lockformat}   || '[[$url][Lock Topic]]';
    my $unlockformat = $params->{unlockformat} || '[[$url][Unlock Topic]]';
    my $forbiddenformat = $params->{forbiddenformat}
      || '<font color="#bbbbbb">Unlock Topic</font>';

    Foswiki::Func::writeDebug(
"$pluginName( $web $topic - $lockformat - $unlockformat - $forbiddenformat)"
    ) if DEBUG;

    if ( $topic && !Foswiki::Func::topicExists( $web, $topic ) ) {
        return "Warning: $topic does not exist.";
    }

    my $user      = Foswiki::Func::getWikiName();
    my $isAllowed = 0;
    my ( $meta, $text ) = Foswiki::Func::readTopic( $web, $topic );

    if ( $user ne $Foswiki::cfg{DefaultUserWikiName} ) {
        $isAllowed =
          Foswiki::Func::checkAccessPermission( 'CHANGE', $user, $text, $topic,
            $web, $meta );
    }
    Foswiki::Func::writeDebug("$pluginName: $user - $isAllowed") if DEBUG;

    if ( !$isAllowed ) {
        return _expandFormat( $web, $topic, $forbiddenformat );
    }

    if ( $text =~ m/<!-- TOPICLOCK/ ) {
        return _expandFormat( $web, $topic, $unlockformat );
    }
    else {
        return _expandFormat( $web, $topic, $lockformat );
    }
}

sub _toggleLock {
    my $session  = shift;
    my $query    = Foswiki::Func::getCgiQuery();
    my $theWeb   = _sanatize( $query->param("lockweb") ) || undef;
    my $theTopic = _sanatize( $query->param("locktopic") ) || undef;
    my $user     = Foswiki::Func::getWikiName();

    # check preconditions
    #
    if ( !defined($theWeb) ) {
        $session->{response}->status(500);
        return "<h1>500 Missing parameter: lockweb</h1>";
    }

    if ( !defined($theTopic) ) {
        $session->{response}->status(500);
        return "<h1>500 Missing parameter: locktopic</h1>";
    }

    if ( !Foswiki::Func::topicExists( $theWeb, $theTopic ) ) {
        $session->{response}->status(500);
        return "<h1>500 Topic does not exist.</h1>";
    }

    if (
        !Foswiki::Func::checkAccessPermission(
            'CHANGE', Foswiki::Func::getWikiName(),
            undef,    $theTopic,
            $theWeb,  undef
        )
      )
    {
        $session->{response}->status(403);
        return "<h1>403 Forbidden</h1>";
    }

    # do the job
    #
    my ( $meta, $text ) = Foswiki::Func::readTopic( $theWeb, $theTopic );

    if ( $text =~ m/<!-- TOPICLOCK/ ) {
        $text =~ s/<!-- TOPICLOCK.*?-->//sm;
    }
    else {
        $text .=
"\n<!-- TOPICLOCK\n   * Set ALLOWTOPICVIEW = $user\n   * Set ALLOWTOPICCHANGE = $user\n-->\n";
    }
    my $error = Foswiki::Func::saveTopic( $theWeb, $theTopic, $meta, $text );

    if ( !$error ) {
        Foswiki::Func::redirectCgiQuery( undef,
            Foswiki::Func::getScriptUrl( $theWeb, $theTopic, "view" ), 0 );
        return "Lock changed. Redirecting...\n\n";
    }
    else {
        return "$error";
    }
}

1;
__END__
This copyright information applies to the TopicLockPlugin:

# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# TopicLockPlugin is (c) 2010 Oliver Krueger, wiki-one.net
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#
# For licensing info read LICENSE file in the root of this distribution.
