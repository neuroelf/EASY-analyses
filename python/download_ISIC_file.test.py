import getpass
import urllib.request as urllib2

# ISIC base URL
ISICBaseURL = 'https://isic-archive.com'

# request username and password (without output to console)
username = input('Please enter your ISIC username: ')
password = getpass.getpass('Please enter your ISIC password: ')

# create the password manager
manager = urllib2.HTTPPasswordMgrWithDefaultRealm()
manager.add_password(None, ISICBaseURL, username, password)

# create the authentication handler using the password manager
auth = urllib2.HTTPBasicAuthHandler(manager)

# create the opener that will replace the default urlopen method on further calls
opener = urllib2.build_opener(auth)
urllib2.install_opener(opener)

# test retrieving an image into a local file (this particular one doesn't require AUTH!)
response = urllib2.urlretrieve(baseurl + "/api/v1/image/5436e3abbae478396759f0cf/download", 'ISIC_0000000.jpg')

