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

package storage::netapp::ontap::snmp::mode::listclusternodes;

use base qw(centreon::plugins::mode);

use strict;
use warnings;

sub new {
    my ($class, %options) = @_;
    my $self = $class->SUPER::new(package => __PACKAGE__, %options);
    bless $self, $class;

    $options{options}->add_options(arguments => {});

    return $self;
}

sub check_options {
    my ($self, %options) = @_;
    $self->SUPER::init(%options);
}

my $mapping = {
    location => { oid => '.1.3.6.1.4.1.789.1.25.2.1.3' }, # nodeLocation
    model    => { oid => '.1.3.6.1.4.1.789.1.25.2.1.4' }, # nodeModel
    product  => { oid => '.1.3.6.1.4.1.789.1.25.2.1.23' }, # nodeProductVersion
    firmware => { oid => '.1.3.6.1.4.1.789.1.25.2.1.24' }  # nodeFirmwareVersion
};

sub manage_selection {
    my ($self, %options) = @_;

    my $oid_name = '.1.3.6.1.4.1.789.1.25.2.1.1'; # nodeName
    my $snmp_result = $options{snmp}->get_table(oid => $oid_name);
    my $results = {};
    foreach (keys %$snmp_result) {
        /^$oid_name\.(.*)$/;

        $results->{$1} = { name => $snmp_result->{$_} };
    }

    $options{snmp}->load(
        oids => [ map($_->{oid}, values(%$mapping)) ],
        instances => [ map($_, keys(%$results)) ],
        instance_regexp => '^(.*)$'
    );
    $snmp_result = $options{snmp}->get_leef();
    foreach (keys %$results) {
        my $result = $options{snmp}->map_instance(mapping => $mapping, results => $snmp_result, instance => $_);

        $results->{$_} = { %$result, %{$results->{$_}} };
    }

    return $results;
}

sub run {
    my ($self, %options) = @_;

    my $results = $self->manage_selection(snmp => $options{snmp});
    foreach my $instance (sort keys %$results) {
        $self->{output}->output_add(long_msg => 
            join('', map("[$_ = " . $results->{$instance}->{$_} . ']', ('name', keys(%$mapping))))
        );
    }

    $self->{output}->output_add(
        severity => 'OK',
        short_msg => 'List cluster nodes:'
    );
    $self->{output}->display(nolabel => 1, force_ignore_perfdata => 1, force_long_output => 1);
    $self->{output}->exit();
}

sub disco_format {
    my ($self, %options) = @_;

    $self->{output}->add_disco_format(elements => ['name', keys %$mapping]);
}

sub disco_show {
    my ($self, %options) = @_;

    my $results = $self->manage_selection(snmp => $options{snmp});
    foreach (sort keys %$results) {        
        $self->{output}->add_disco_entry(
            %{$results->{$_}}
        );
    }
}
1;

__END__

=head1 MODE

List cluster nodes.

=over 8

=back

=cut
