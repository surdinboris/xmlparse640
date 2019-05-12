import telnetlib
import time
import re

# pdus={'10.160.231.171': [1, 2], '10.160.231.170': [3, 4]}#, '10.160.231.169', '10.160.231.168']
pdus={'192.168.1.254': [1]}



failoverresult= {'PDU-1': {'result': 'na'},'PDU-2': {'result': 'na'},'PDU-3': {'result': 'na'},'PDU-4': {'result': 'na'}}
tempsensnames = {1: 'A', 2: 'B', 3: 'A', 4: 'B'}

sensors = {'sensor1': 'Front-Down', 'sensor2': 'Front-Up', 'sensor3': 'Rear-Down', 'sensor4': 'Rear-Up'}
def sendcom(tel, cmd=b""):
    tel.write(cmd)
    tel.write(bytes("\r", encoding='ascii'))


def login(tel):
    user = 'admn'
    password = 'wildcat1'
    tel.read_until(b"Username:")
    sendcom(tel, user.encode())
    tel.read_until(b"Password:")
    sendcom(tel, password.encode())
    tel.read_until(b"Switched CDU:")

def pdu_command(host, cmd):
    tel = telnetlib.Telnet(host)
    login(tel)
    # print(cmd.encode())
    sendcom(tel, cmd.encode())
    # tel.read_until(b"Command successful")
    # print('y/n')
    # sendcom(tel,'y'.encode())
    tel.read_until(b"Switched CDU:")
    sendcom(tel, b'exit')


def sensorscheck(pdu, grp):
    print(pdu, grp)
    with telnetlib.Telnet(pdu) as t:
        t.read_until(b'Username:')
        t.write(b'admn\n')
        t.read_until(b'Password:')
        t.write(b'wildcat1\n')
        t.read_until(b"Switched CDU:")
        t.write(b'envmon\n')
        temp_output = t.read_until(b"Switched CDU:").decode('utf-8')
        print(temp_output)
        t.write(b'sysstat\n')
        pow_output = t.read_until(b"Switched CDU:").decode('utf-8')
        print(pow_output)

        temp = re.search('.*{}1\s*Temp_Humid_Sensor_{}1\s*(\d+|Not Found).*'.format(grp,grp), temp_output).group(1)
        wattage = re.search('Total Power Consumption:\s+(\d+|Not Found)', pow_output).group(1)
        return {'wattage': wattage, 'temp': temp}

print_to_gui = print
for pdu in pdus:
    pgroups=pdus[pdu]
    for pgroup in pgroups:
        print('System powered without PDU-{}'.format(pgroup))
        print_to_gui('turning off PDU-{}'.format(pgroup))
        pdu_command(pdu, 'off {}'.format(pgroup))
        time.sleep(5)
        #if len(nmapscan()) == servers_count:
        if True:
            print_to_gui('All {} system servers are online')#.format(len(nmapscan())))
            pdu_command(pdu, 'on {}'.format(pgroup))
            time.sleep(10)
            failoverresult['PDU-{}'.format(pgroup)]['result'] = 'pass'
        else:
            print_to_gui('Error: found {} active servers, while should be {}')#.format(len(nmapscan()), servers_count))
            pdu_command(pdu, 'on {}'.format(pgroup))
            failoverresult['PDU-{}'.format(pgroup)]['result'] = 'fail'
            #pdu_command(pdu, 'power outlets all on')
            time.sleep(10)


# # Switched CDU: envmon
#
# Environmental Monitor .A
#    Name: Environmental_Monitor_A          Status: Normal
#
#    Temperature/Humidity Sensors
#
#       ID    Name                          Temperature    Humidity
#       .A1   Temp_Humid_Sensor_A1          Not Found      Not Found
#       .A2   Temp_Humid_Sensor_A2          Not Found      Not Found
#
#    Command successful

for wpdu in pdus:
    pgroups = pdus[wpdu]
    for pgroup in pgroups:
        print_to_gui('Checking wattage and temperature for sensor{}'.format(pgroup))
        # creating sensor record
        sensor = failoverresult['PDU-{}'.format(pgroup)]['sensor{}'.format(pgroup)] = {}
        sensorsdata = sensorscheck(wpdu,tempsensnames[pgroup])
        sensor['wattage'] = sensorsdata['wattage']
        sensor['temp'] = sensorsdata['temp']

print(failoverresult)