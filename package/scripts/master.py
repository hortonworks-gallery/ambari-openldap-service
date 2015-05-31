import sys, os, pwd, signal, time
from resource_management import *
from subprocess import call

class Master(Script):
  def install(self, env):
    # Install packages listed in metainfo.xml
    self.install_packages(env)
    self.configure(env)
    import params

    #e.g. /var/lib/ambari-agent/cache/stacks/HDP/2.2/services/openldap-stack/package
    service_packagedir = os.path.realpath(__file__).split('/scripts')[0] 

    #Ensure the shell scripts in the services dir are executable         
    Execute('find '+service_packagedir+' -iname "*.sh" | xargs chmod +x')

    Execute('echo "Running ' + service_packagedir + '/scripts/setup.sh"')
    
    # run setup script which has simple shell setup
    Execute(service_packagedir + '/scripts/setup.sh ' + params.ldap_password + ' ' + params.ldap_adminuser + ' ' + params.ldap_domain + ' ' + params.ldap_ldifdir + ' ' + params.ldap_ou + ' >> ' + params.stack_log)


  def configure(self, env):
    import params
    env.set_params(params)


  def stop(self, env):
    import params
    Execute('service slapd stop')
    #Execute(params.stack_dir + '/package/scripts/stop.sh >> ' + params.stack_log)
      
  def start(self, env):
    import params
    Execute('service slapd start')
    #Execute(params.stack_dir + '/package/scripts/start.sh >> ' + params.stack_log)
	

  def status(self, env):
    import params
    Execute('service slapd status')
    #Execute(params.stack_dir + '/package/scripts/status.sh >> ' + params.stack_log)

if __name__ == "__main__":
  Master().execute()
