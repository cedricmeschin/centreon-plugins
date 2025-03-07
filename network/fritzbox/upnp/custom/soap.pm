#
# Copyright 2021 Centreon (http://www.centreon.com/)
#
# Centreon is a full-fledged industry-strength solution that meets
# the needs in IT infrastructure and application monitoring for
# service performance.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

package network::fritzbox::upnp::custom::soap;

use strict;
use warnings;
use centreon::plugins::http;
use XML::LibXML::Simple;

sub new {
    my ($class, %options) = @_;
    my $self  = {};
    bless $self, $class;

    if (!defined($options{output})) {
        print "Class Custom: Need to specify 'output' argument.\n";
        exit 3;
    }
    if (!defined($options{options})) {
        $options{output}->add_option_msg(short_msg => "Class Custom: Need to specify 'options' argument.");
        $options{output}->option_exit();
    }

    if (!defined($options{noptions})) {
        $options{options}->add_options(arguments => {
            'hostname:s'     => { name => 'hostname' },
            'port:s'         => { name => 'port' },
            'proto:s'        => { name => 'proto' },
            'api-username:s' => { name => 'api_username' },
            'api-password:s' => { name => 'api_password' },
            'timeout:s'      => { name => 'timeout' },
            'agent:s'        => { name => 'agent' },
            'unknown-http-status:s'  => { name => 'unknown_http_status' },
            'warning-http-status:s'  => { name => 'warning_http_status' },
            'critical-http-status:s' => { name => 'critical_http_status' }
        });
    }
    $options{options}->add_help(package => __PACKAGE__, sections => 'UNPNP API OPTIONS', once => 1);

    $self->{output} = $options{output};
    $self->{http} = centreon::plugins::http->new(%options);

    return $self;
}

sub set_options {
    my ($self, %options) = @_;

    $self->{option_results} = $options{option_results};
}

sub set_defaults {}

sub check_options {
    my ($self, %options) = @_;

    $self->{hostname} = (defined($self->{option_results}->{hostname})) ? $self->{option_results}->{hostname} : '';
    $self->{port} = (defined($self->{option_results}->{port})) ? $self->{option_results}->{port} : 49000;
    $self->{proto} = (defined($self->{option_results}->{proto})) ? $self->{option_results}->{proto} : 'http';
    $self->{api_username} = (defined($self->{option_results}->{api_username})) ? $self->{option_results}->{api_username} : '';
    $self->{api_password} = (defined($self->{option_results}->{api_password})) ? $self->{option_results}->{api_password} : '';
    $self->{timeout} = (defined($self->{option_results}->{timeout})) ? $self->{option_results}->{timeout} : 30;
    $self->{agent} = (defined($self->{option_results}->{agent}) && $self->{option_results}->{agent} ne '') ? 
        $self->{option_results}->{agent} : 'igdupnp';
    $self->{unknown_http_status} = (defined($self->{option_results}->{unknown_http_status})) ? $self->{option_results}->{unknown_http_status} : '%{http_code} < 200 or %{http_code} >= 300';
    $self->{warning_http_status} = (defined($self->{option_results}->{warning_http_status})) ? $self->{option_results}->{warning_http_status} : '';
    $self->{critical_http_status} = (defined($self->{option_results}->{critical_http_status})) ? $self->{option_results}->{critical_http_status} : '';

    if ($self->{hostname} eq '') {
        $self->{output}->add_option_msg(short_msg => "Need to specify --hostname option.");
        $self->{output}->option_exit();
    }

    return 0;
}

sub build_options_for_httplib {
    my ($self, %options) = @_;

    $self->{option_results}->{hostname} = $self->{hostname};
    $self->{option_results}->{timeout} = $self->{timeout};
    $self->{option_results}->{port} = $self->{port};
    $self->{option_results}->{proto} = $self->{proto};
    if (defined($self->{api_username}) && $self->{api_username} ne '') {
        $self->{option_results}->{username} = $self->{api_username};
        $self->{option_results}->{password} = $self->{api_password};
        $self->{option_results}->{credentials} = 1;
        $self->{option_results}->{basic} = 1;
    }
}

sub settings {
    my ($self, %options) = @_;

    $self->build_options_for_httplib();
    $self->{http}->set_options(%{$self->{option_results}});
}

sub get_hostname {
    my ($self, %options) = @_;

    return $self->{hostname};
}

sub get_port {
    my ($self, %options) = @_;

    return $self->{port};
}

sub request {
    my ($self, %options) = @_;

    $self->settings();
    my $data = <<END_FILE;
<?xml version="1.0" encoding="utf-8"?>
<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
    <s:Body>
        <u:$options{verb} xmlns:u="urn:schemas-upnp-org:service:$options{ns}:1" />
    </s:Body>
</s:Envelope>
END_FILE

    my $content = $self->{http}->request(
        method => 'POST',
        url_path => '/' . $self->{agent} . '/control/' . $options{url},
        header => [
            'SOAPAction: urn:schemas-upnp-org:service:' . $options{ns} . ':1#' . $options{verb},
            'Content-type: text/xml'
        ],
        query_form_post => $data,
        unknown_status => '(%{http_code} < 200 or %{http_code} >= 300) and %{http_code} != 500',
        warning_status => '',
        critical_status => ''
    );

    my $xml_result;
    eval {
        $SIG{__WARN__} = sub {};
        $xml_result = XMLin($content, ForceArray => [], KeyAttr => []);
    };
    if ($@) {
        $self->{output}->add_option_msg(short_msg => "Cannot decode xml response: $@");
        $self->{output}->option_exit();
    }
    if (defined($xml_result->{'soapenv:Body'}->{'soapenv:Fault'})) {
        $self->{output}->add_option_msg(short_msg => 'soap response issue');
        $self->{output}->option_exit();
    }

    return $xml_result;
}

1;

__END__

=head1 NAME

UPNP SOAP API

=head1 SYNOPSIS

UPNP SOAP API

=head1 UNPNP API OPTIONS

=over 8

=item B<--hostname>

API hostname.

=item B<--port>

API port (Default: 49000)

=item B<--proto>

Specify https if needed (Default: 'http')

=item B<--agent>

Fritzbox has two different UPNP agents: upnp or igdupnp (Default: igdupnp).

=item B<--api-username>

Set API username

=item B<--api-password>

Set API password

=item B<--timeout>

Set HTTP timeout

=back

=head1 DESCRIPTION

B<custom>.

=cut
