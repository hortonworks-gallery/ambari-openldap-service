#!/usr/bin/env python
from resource_management.libraries.functions.version import format_hdp_stack_version, compare_versions
from resource_management import *

# server configurations
config = Script.get_config()

stack_dir = config['configurations']['openldap-config']['stack.dir']

stack_log = config['configurations']['openldap-config']['stack.log']

ldap_adminuser = config['configurations']['openldap-config']['ldap.adminuser']

ldap_domain = config['configurations']['openldap-config']['ldap.domain']

ldap_password = config['configurations']['openldap-config']['ldap.password']

ldap_ldifdir = config['configurations']['openldap-config']['ldap.ldifdir']

