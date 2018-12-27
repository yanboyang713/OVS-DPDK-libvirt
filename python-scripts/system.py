import sys
import platform
class system(object):
    def __init__(self):
        self.distributionName = platform.linux_distribution()

    def getSystemDistribution(self):
        return self.distributionName[0]

    def getSystemVersion(self):
        return self.distributionName[1]

    def setEnvVar(envName, envValue):
        os.environ[envName] = envValue

    def getEnvVar(envName):
        return os.environ[envName]
