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

package network::stormshield::snmp::mode::components::fan;

use strict;
use warnings;

my $mapping = {
    name   => { oid => '.1.3.6.1.4.1.11256.1.10.9.1.2' }, # snsFanName
    status => { oid => '.1.3.6.1.4.1.11256.1.10.9.1.3' }, # snsFanStatus
    rpm    => { oid => '.1.3.6.1.4.1.11256.1.10.9.1.4' } # snsFanRpm
};
my $oid_fanEntry = '.1.3.6.1.4.1.11256.1.10.9.1'; # snsFanEntry

sub load {
    my ($self) = @_;
    
    push @{$self->{request}}, { 
        oid => $oid_fanEntry,
        start => $mapping->{name}->{oid}
    };
}

sub check {
    my ($self) = @_;

    $self->{output}->output_add(long_msg => 'checking fans');
    $self->{components}->{fan} = { name => 'fans', total => 0, skip => 0 };
    return if ($self->check_filter(section => 'fan'));

    my ($exit, $warn, $crit, $checked);
    foreach my $oid ($self->{snmp}->oid_lex_sort(keys %{$self->{results}->{ $oid_fanEntry }})) {
        next if ($oid !~ /^$mapping->{name}->{oid}\.(.*)$/);
        my $instance = $1;

        my $result = $self->{snmp}->map_instance(mapping => $mapping, results => $self->{results}->{ $oid_fanEntry }, instance => $instance);

        next if ($self->check_filter(section => 'fan', instance => $instance));

        $self->{components}->{fan}->{total}++;
        $self->{output}->output_add(
            long_msg => sprintf(
                "fan '%s' status is '%s' [instance: %s, rpm: %s]",
                $result->{name}, $result->{status}, $instance, $result->{rpm}
            )
        );

        $exit = $self->get_severity(section => 'fan', value => $result->{status});
        if (!$self->{output}->is_status(value => $exit, compare => 'ok', litteral => 1)) {
            $self->{output}->output_add(
                severity => $exit,
                short_msg => sprintf(
                    "Fan '%s' status is '%s'", $result->{name}, $result->{status}
                )
            );
        }

        ($exit, $warn, $crit, $checked) = $self->get_severity_numeric(section => 'fan', instance => $instance, value => $result->{rpm});            
        if (!$self->{output}->is_status(value => $exit, compare => 'ok', litteral => 1)) {
            $self->{output}->output_add(
                severity => $exit,
                short_msg => sprintf(
                    "fan '%s' speed is '%s' rpm", $result->{name}, $result->{rpm}
                )
            );
        }
        $self->{output}->perfdata_add(
            nlabel => 'hardware.fan.speed.rpm',
            unit => 'rpm',
            instances => $result->{fanName},
            value => $result->{fanValue},
            warning => $warn,
            critical => $crit, min => 0
        );
    }
}

1;
