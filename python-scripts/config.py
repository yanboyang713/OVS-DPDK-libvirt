class config(object):
    def __init__(self, configFileName = ".config"):
        self.configFileName = configFileName

        '''
        all of dict type of variable is structure data. key:[name, value have be changed or not] value:[value, and comment]
        '''
        self.OVS_ENV_DIC = {}
        self.OVS_CONFIG_DIC = {}

        self.DPDK_ENV_DIC = {}
        self.DPDK_CONFIG_DIC = {}

        self.LIBVIRT_ENV_DIC = {}
        self.LIBVIRT_CONFIG_DIC = {}

        self.readConfigFile()

    #this func is for distction envirment var and config info write to different dict
    def analysisText(self, mark, text):
        if len(text) != 0 and text[0] != "#": # "#" is comment or empty
            print ("text = ", text)
            isEnv = self.isEnvNotConfig(text)
            if isEnv == True:
                text = text[7:]
            name, value = text.split('=')
            print (name, value)

            #LIBVIRT
            if mark == "LIBVIRT" and isEnv == True:
                self.LIBVIRT_ENV_DIC[(name, False)] = [value, "NONE"] #True mean value have changed
            elif mark == "LIBVIRT" and isEnv == False:
                self.LIBVIRT_CONFIG_DIC[(name, False)] = [value, "NONE"] #True mean value have changed

            #DPDK
            elif mark == "DPDK" and isEnv == True:
                self.DPDK_ENV_DIC[(name, False)] = [value, "NONE"] #True mean value have changed
            elif mark == "DPDK" and isEnv == False:
                self.DPDK_CONFIG_DIC[(name, False)] = [value, "NONE"] #True mean value have changed

            #OVS
            elif mark == "OVS" and isEnv == True:
                self.OVS_ENV_DIC[(name, False)] = [value, "NONE"] #True mean value have changed
            elif mark == "OVS" and isEnv == False:
                self.OVS_CONFIG_DIC[(name, False)] = [value, "NONE"] #True mean value have changed


    def isEnvNotConfig(self, text):
        text = text[:6]
        if text == "export":
            return True
        return False

    def readConfigFile(self):
        file = open(self.configFileName, "r")
        while True:
            line = file.readline().strip().replace(" ", "")
            if line == "LIBVIRT={":
                while line != "}":
                    line = file.readline().strip()
                    if (line != "}"):
                        self.analysisText("LIBVIRT", line)

            elif line == "DPDK={":
                while line != "}":
                    line = file.readline().strip()
                    if (line != "}"):
                        self.analysisText("DPDK", line)

            elif line == "OVS={":
                while line != "}":
                    line = file.readline().strip()
                    if (line != "}"):
                        self.analysisText("OVS", line)

            elif line == "END":
                break


    def writeConfigFile():
        print ("test")
