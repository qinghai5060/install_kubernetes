#!/usr/bin/expect -f
set timeout 600
exp_internal 0

set filelist hosts
set user1 paas
set user2 root
set supportsshkey n

set pass1 test@123

set needconfirmation N

set file muti_exec.log
log_file $file;

set pass2 test12#$

set fd "$filelist"
set fp [open "$fd" r]
set data [read $fp]

foreach line $data {
        spawn ssh -l $user1 $line
        
        if { $supportsshkey == "N" ||  $supportsshkey == "n"  } {
                expect {
                        "(yes/no)?"
                        {
                                send "yes\r"
                                exp_continue
                        }
                        "*assword:" { send "$pass1\r" }
                }               
        } else {
                expect "$user1"
                send "ssh $user1@$line\n"
        }

        send_user -- "\n-------------start to login $line with $user1 -------------- "
        expect {
            "*$*" {
                send "su - $user2 \n"
                expect {
                    "*assword:" { 
			            send "$pass2\n" 
        		        expect {
                	        "*#*" {
                        	    send "$cmd\nexit\nexit\n"
                                expect eof                         	
				            }
                            "Authentication failure" {
                                send_user "\nAuthentication failure when login $line, program quit!\n"
        	                    exit  
                            }
                	        "Permission denied" {
	                            send_user "\nPermission denied when login $line, program quit!\n"
        	                    exit
	               		    }
			            }
		            }
                    "su: user $user2 does not exist" {
                        send_user "\nVerification failed:user $user2 does not exist, program quit!\n"
                        exit
                    }
                }
            }
            "*#*" {
                send "su - $user2 \n"
                expect {
                    "*assword:" { 
			            send "$pass2\n" 
        		        expect {
                	        "*#*" {
                        	    send "$cmd \nexit\nexit\n"
                                expect eof           					
				            }
                	        "Permission denied" {
	                            send_user "\nPermission denied, program quit!\n"
        	                    exit
	               		    }
                            "Authentication failure" {
                                send_user "\nAuthentication failure when login $line, program quit!\n"
        	                    exit  
                            }
			            }
		            }
                    "su: user $user2 does not exist" {
                        send_user "\nuser $user2 does not exist!\n"
                        exit
                    }
                }
            }
            "*assword:" { 
                send_user "\nPassword for user($user2) may be not right, program quit!\n"
                exit   
            }
            "$user1" { 
                send "su - $user2 \n"
                expect {
                    "*assword:" { 
			            send "$pass2\n" 
        		        expect {
                	        "*#*" {
                        	    send "$cmd \nexit\nexit\n"
                                expect eof          					
				            }
                	        "Permission denied" {
	                            send_user "\nPermission denied, program quit!\n"
        	                    exit
	               		    }
                            "Authentication failure" {
                                send_user "\nAuthentication failure when login $line, program quit!\n"
        	                    exit  
                            }
			            }
		            }
                    "su: user $user2 does not exist" {
                        send_user "\nuser $user2 does not exist!\n"
                        exit
                    }
                }   
            }
            "Permission denied*" {
                send_user "\nPermission denied, program quit!\n"
                exit   
            }
            "Authentication failure" {
                send_user "\nAuthentication failure when login $line, program quit!\n"
        	    exit  
            }
            timeout {
                send_user "\nTimeout, program quit!\n"
                exit
            }
        }
        
        send_user -- "\n--------------Host($line )has been finished!-------------\n"
}