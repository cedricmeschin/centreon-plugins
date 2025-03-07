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

package storage::qnap::snmp::mode::hardware;

use base qw(centreon::plugins::templates::hardware);

use strict;
use warnings;

sub set_system {
    my ($self, %options) = @_;

    $self->{regexp_threshold_numeric_check_section_option} =
        '^(?:temperature|disk|smartdisk|fan|psu\.fanspeed|psu\.temperature)$';

    $self->{cb_hook2} = 'snmp_execute';
    
    $self->{thresholds} = {
        disk => [
            ['good', 'OK'],
            ['warning', 'WARNING'],
            ['abnormal', 'CRITICAL'],

            ['in-use', 'OK'], # es
            ['noDisk', 'OK'],
            ['ready', 'OK'],
            ['invalid', 'CRITICAL'],
            ['rwError', 'CRITICAL'],
            ['unknown', 'UNKNOWN'],
            ['error', 'CRITICAL']
        ],
        fan => [
            ['ok', 'OK'],
            ['n/a', 'OK'],
            ['fail', 'CRITICAL']
        ],
        psu => [
            ['ok', 'OK'],
            ['fail', 'CRITICAL']
        ],
        smartdisk => [
            ['good', 'OK'],
            ['warning', 'WARNING'],
            ['abnormal', 'CRITICAL'],
            ['error', 'CRITICAL'],

            ['GOOD', 'OK'],
            ['NORMAL', 'OK'],
            ['--', 'OK'],
            ['.*', 'CRITICAL']
        ],
        raid => [
            ['Ready', 'OK'],
            ['Synchronizing', 'OK'],
            ['degraded', 'WARNING'],
            ['.*', 'CRITICAL']
        ]
    };

    $self->{components_path} = 'storage::qnap::snmp::mode::components';
    $self->{components_module} = ['disk', 'fan', 'mdisk', 'psu', 'raid', 'temperature'];
}

sub snmp_execute {
    my ($self, %options) = @_;

    $self->{snmp} = $options{snmp};

    $self->{is_es} = 0;
    $self->{is_qts} = 0;
    my $oid_es_uptime = '.1.3.6.1.4.1.24681.2.2.4.0'; # es-SystemUptime
    my $oid_qts_model = '.1.3.6.1.4.1.55062.1.12.3.0'; # systemModel
    my $snmp_result = $self->{snmp}->get_leef(
        oids => [$oid_es_uptime, $oid_qts_model]
    ); 
    if (defined($snmp_result->{$oid_es_uptime})) {
        $self->{is_es} = 1;
    }
    if (defined($snmp_result->{$oid_qts_model})) {
        $self->{is_qts} = 1;
    }
}

sub new {
    my ($class, %options) = @_;
    my $self = $class->SUPER::new(package => __PACKAGE__, %options, force_new_perfdata => 1);
    bless $self, $class;

    $options{options}->add_options(arguments => {});

    return $self;
}

1;

__END__

=head1 MODE

Check hardware.

=over 8

=item B<--component>

Which component to check (Default: '.*').
Can be: 'disk', 'fan', 'mdisk', 'psu', 'raid', 'temperature'.

=item B<--filter>

Exclude some parts (comma seperated list) (Example: --filter=disk)
Can also exclude specific instance: --filter=disk,1

=item B<--absent-problem>

Return an error if an entity is not 'present' (default is skipping) (comma seperated list)
Can be specific or global: --absent-problem=disk

=item B<--no-component>

Return an error if no compenents are checked.
If total (with skipped) is 0. (Default: 'critical' returns).

=item B<--threshold-overload>

Set to overload default threshold values (syntax: section,status,regexp)
It used before default thresholds (order stays).
Example: --threshold-overload='disk,CRITICAL,^(?!(ready)$)'

=item B<--warning>

Set warning threshold for temperatures (syntax: type,regexp,threshold)
Example: --warning='temperature,cpu,30' --warning='fan,.*,1500'

=item B<--critical>

Set critical threshold for temperatures (syntax: type,regexp,threshold)
Example: --critical='temperature,system,40' --critical='disk,.*,40'

=back

=cut
