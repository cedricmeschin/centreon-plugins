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

package apps::java::awa::jmx::mode::agent;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;
use centreon::plugins::misc;
use DateTime;
use centreon::plugins::templates::catalog_functions qw(catalog_status_threshold);

sub custom_status_output {
    my ($self, %options) = @_;
    
    my $msg = 'active : ' . $self->{result_values}->{active} . ' [IpAddress: ' . $self->{result_values}->{ipaddress} . ' ]' . 
        '[LastCheck: ' . centreon::plugins::misc::change_seconds(value => $self->{result_values}->{since}) . ']';
    return $msg;
}

sub custom_status_calc {
    my ($self, %options) = @_;
    
    $self->{result_values}->{since} = $options{new_datas}->{$self->{instance} . '_since'};
    $self->{result_values}->{ipaddress} = $options{new_datas}->{$self->{instance} . '_ipaddress'};
    $self->{result_values}->{active} = $options{new_datas}->{$self->{instance} . '_active'};
    $self->{result_values}->{display} = $options{new_datas}->{$self->{instance} . '_display'};
    return 0;
}

sub set_counters {
    my ($self, %options) = @_;
    
    $self->{maps_counters_type} = [
        { name => 'agent', type => 1, cb_prefix_output => 'prefix_agent_output', message_multiple => 'All agents are ok', skipped_code => { -10 => 1 } },
    ];

    $self->{maps_counters}->{agent} = [
        { label => 'status', threshold => 0, set => {
                key_values => [ { name => 'active' }, { name => 'ipaddress' }, { name => 'since' }, { name => 'display' } ],
                closure_custom_calc => $self->can('custom_status_calc'),
                closure_custom_output => $self->can('custom_status_output'),
                closure_custom_perfdata => sub { return 0; },
                closure_custom_threshold_check => \&catalog_status_threshold,
            }
        },
    ];
}

sub new {
    my ($class, %options) = @_;
    my $self = $class->SUPER::new(package => __PACKAGE__, %options);
    bless $self, $class;
    
    $options{options}->add_options(arguments =>
                                { 
                                  "filter-name:s"       => { name => 'filter_name' },
                                  "warning-status:s"    => { name => 'warning_status', default => '' },
                                  "critical-status:s"   => { name => 'critical_status', default => '' },
                                  "timezone:s"          => { name => 'timezone' },
                                });
    
    return $self;
}

sub check_options {
    my ($self, %options) = @_;
    $self->SUPER::check_options(%options);

    $self->change_macros(macros => ['warning_status', 'critical_status']);
    $self->{option_results}->{timezone} = 'GMT' if (!defined($self->{option_results}->{timezone}) || $self->{option_results}->{timezone} eq '');
}

sub prefix_agent_output {
    my ($self, %options) = @_;
    
    return "Agent '" . $options{instance_value}->{display} . "' ";
}

sub manage_selection {
    my ($self, %options) = @_;
    
    $self->{app} = {};
    $self->{request} = [
         { mbean => 'Automic:name=*,side=Agents,type=*',
          attributes => [ { name => 'LastCheck' }, { name => 'IpAddress' }, 
                          { name => 'Active' }, { name => 'Name' } ] },
    ];
    my $result = $options{custom}->get_attributes(request => $self->{request}, nothing_quit => 1);
    my $tz = centreon::plugins::misc::set_timezone(name => $self->{option_results}->{timezone});
    
    foreach my $mbean (keys %{$result}) {
        $mbean =~ /name=(.*?)(,|$)/i;
        my $name = $1;
        $mbean =~ /type=(.*?)(,|$)/i;
        my $display = $1 . '.' . $name;

        if (defined($self->{option_results}->{filter_name}) && $self->{option_results}->{filter_name} ne '' &&
            $display !~ /$self->{option_results}->{filter_name}/) {
            $self->{output}->output_add(long_msg => "skipping '" . $display . "': no matching filter.", debug => 1);
            next;
        }

        my $agent_infos = {
            display => $display,
            ipaddress => $result->{$mbean}->{IpAddress},
            active => $result->{$mbean}->{Active} ? 'yes' : 'no',
        };

        if ($result->{$mbean}->{LastCheck} =~ /^\s*(\d+)-(\d+)-(\d+)\s+(\d+):(\d+):(\d+)/) {
            my $dt = DateTime->new(
                year       => $1,
                month      => $2,
                day        => $3,
                hour       => $4,
                minute     => $5,
                second     => $6,
                %$tz
            );
          $agent_infos->{since} = time() - $dt->epoch;
        } elsif ($result->{$mbean}->{LastCheck} =~ /^\s*00:00:00/) {
          $agent_infos->{since} = 0;
        } else {
          next;
        }

        $self->{agent}->{$display} = $agent_infos;
    }
    
    if (scalar(keys %{$self->{agent}}) <= 0) {
        $self->{output}->add_option_msg(short_msg => "No agent found.");
        $self->{output}->option_exit();
    }
}

1;

__END__

=head1 MODE

Check agent status.

=over 8

=item B<--filter-name>

Filter agent name (can be a regexp).

=item B<--warning-status>

Set warning threshold for status (Default: '').
Can used special variables like: %{since}, %{display}, %{ipaddress}, %{active}

=item B<--critical-status>

Set critical threshold for status (Default: '').
Can used special variables like: %{since}, %{display}, %{ipaddress}, %{active}

=item B<--timezone>

Timezone options (the date from the equipment overload that option). Default is 'GMT'.

=back

=cut
