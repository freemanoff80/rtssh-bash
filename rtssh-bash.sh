#!/bin/bash

USERNAME=testuser

OPTION=$1

SSH_KEY_PRIVAT='/home/mobaxterm/.ssh/id_rsa_all_01'
SSH_KEY_PUBLIC='/home/mobaxterm/.ssh/id_rsa_all_01.pub'

PROGRAMM_DIR=/home/mobaxterm/_workspace/_projects/rtssh-bash
BASE_DIR=base-lists

LIST_HOSTNAMES=$PROGRAMM_DIR/$BASE_DIR/.list-hostnames
LIST_PORTS=$PROGRAMM_DIR/$BASE_DIR/.list-ports
LIST_PASSWORDS=$PROGRAMM_DIR/$BASE_DIR/.list-passwords.gpg


if [ ! -f $LIST_HOSTNAMES ]; then
    touch $LIST_HOSTNAMES
fi

if [ ! -f $LIST_PORTS ]; then
    echo "!!! LIST $LIST_PORTS NOT EXIST";
    exit 0;
fi

if [ ! -f $LIST_PASSWORDS ]; then
    echo "!!! LIST $LIST_PASSWORDS NOT EXIST";
    exit 0;
fi


case "$OPTION" in


    ### Option for connection to host
    '-c' | '--connect' | 'conn' )

    if [ -z $2 ]; then
        
        echo '--- HOST NOT SPECIFIED';
        exit 1;

    elif [ -f $2 ]; then
        
        HOSTS_ARRAY=($( cat $2 |grep -v -e "^#" ))
        #echo "${HOSTS_ARRAY[*]}";

    else
        
        HOSTS_ARRAY=($2)

    fi


    PORTS_ARRAY=($( cat $LIST_PORTS |grep -v -e "^#" ))
    #echo "${PORTS_ARRAY[*]}";

    if [ ${#PORTS_ARRAY[*]} -eq 0 ]; then

        echo "!!! PORTS LIST IS EMPTY. ADD PORTS IN $LIST_PORTS";
        exit 0;

    fi


    PASS_TRIG=0;                ### Triger for open password list one time
    CHANGE_EXP_PASS_TRIG=0;     ### Triger for change password to new password, if change when it expired 
    
    HOST_NUMBER=0;

    for HOST in ${HOSTS_ARRAY[*]};
    do

        (( HOST_NUMBER++ ));

        echo -e "\n### $HOST_NUMBER >>> CONNECT TO -> $HOST";

        COUNT=0
        STAGE=1 
    
        while true;
            do

            if [ $STAGE = 1 ]; then
    
                ### Check Hostname in Base List
                HOST_PORT=$(grep $HOST $LIST_HOSTNAMES)
    
                if [ -z $HOST_PORT ]; then
                    
                    echo -e "--- NOT HOSTNAME IN BASE LIST"
                    echo -e ">>> CHECK CONNECT TO PORT"
    
                    COUNT=${#PORTS_ARRAY[*]};
           
                    for PORT in ${PORTS_ARRAY[*]};
                        do
                            (( COUNT-- ));
            
                            OUTPUT=$(nc -vz -w 3 $HOST $PORT 2>&1 );
                            RESULT=$?;
            
                            if [ $RESULT -eq 0 ]; then
                                
                                echo "+++ CONNECT PORT $PORT";
                                echo $OUTPUT;
                                if [ -z $(cat $LIST_HOSTNAMES | grep "$HOST:$PORT") ]; then
    
                                    echo "+++ HOST $HOST ADDED TO BASE LIST";
                                    echo "$HOST:$PORT" >> $LIST_HOSTNAMES;
            
                                fi
                                (( STAGE=2 ));
                                break;
            
                            else
                                
                                if [ $COUNT -lt 1 ]; then
                                    
                                    echo "--- NOT CONNECT";
                                    echo $OUTPUT;
                                    (( STAGE=4 ));
                                
                                fi
                            
                            fi
                        done
            
                else
                    
                    echo -e "+++ HOSTNAME EXIST IN BASE LIST"
                    HOST=$(echo $HOST_PORT|cut -d ":" -f 1 );
                    PORT=$(echo $HOST_PORT|cut -d ":" -f 2 );
                    (( STAGE=2 ));
            
                fi
    
            fi
    
            if [ $STAGE = 2 ]; then
    
                ### Check SSH Connect by ssh-key
                echo '>>> CHECK SSH CONNECT BY SSH-KEY'
                OUTPUT=$( ssh -q -o BatchMode=yes -o StrictHostKeyChecking=no -i $SSH_KEY_PRIVAT -p $PORT $USERNAME@$HOST 'echo' 2>&1 )
                RESULT=$?;
            
                if [ $RESULT -eq 0 ]; then
    
                    echo '+++ CONNECTED BY SSH-KEY';
    
                    MATCH_LINE=$(cat $LIST_HOSTNAMES | grep "$HOST:$PORT")
    
                    if [ -z $MATCH_LINE ]; then
    
                        echo "$HOST:$PORT:KEY" >> $LIST_HOSTNAMES;
    
                    elif [ "$MATCH_LINE" = "$HOST:$PORT" ]; then
    
                        sed -i "s/$HOST:$PORT/$HOST:$PORT:KEY/" $LIST_HOSTNAMES;
    
                    fi
    
                    if [ -z "$3" ]; then
         
                        ssh -i $SSH_KEY_PRIVAT -p $PORT $USERNAME@$HOST
                        exit 0;
        
                    else
        
                        SSH_COMMAND=$3
                        ssh -i $SSH_KEY_PRIVAT -p $PORT $USERNAME@$HOST "$SSH_COMMAND"
                        break;
         
                    fi
        
                else
        
                    echo '--- NOT CONNECT BY SSH-KEY';
                    (( STAGE=3 ));
            
                fi
            fi
    
            if [ $STAGE = 3 ]; then
    
                ### Check Password SSH connection
                echo '>>> CHECK SSH CONNECT BY PASSWORD'
            
                if [ $PASS_TRIG = 0 ]; then
    
                    PASSWORD_ARRAY=($( gpg -d -q $LIST_PASSWORDS )) 
                    (( PASS_TRIG=1 )); 
    
                fi
    
            
                if [ ${#PASSWORD_ARRAY[*]} -eq 0 ]; then
                    echo "!!! PASSWORD LIST IS EMPTY";
                    exit 0;
                fi
    
                
                COUNT_PASS_CHECK=${#PASSWORD_ARRAY[*]};
            
                for PASSWORD in ${PASSWORD_ARRAY[*]};
                    do
    
                    if [ $CHANGE_EXP_PASS_TRIG -eq 1 ];then
    
                        #echo -ne ">>> TRYING NEW PASSWORD\r";
                        echo -ne ">>> TRYING NEW PASSWORD\n";
                        PASSWORD=${PASSWORD_ARRAY[1]}; 
                        (( CHANGE_EXP_PASS_TRIG=0 ));
    
                    else
    
                        #echo -ne ">>> TRYING PASSWORD $COUNT_PASS_CHECK\r";
                        echo -ne ">>> TRYING PASSWORD $COUNT_PASS_CHECK\n";
    
                    fi
    
                    (( COUNT_PASS_CHECK-- ));
                
                    #OUTPUT=$( sshpass -p $PASSWORD ssh -o StrictHostKeyChecking=no -p $PORT $USERNAME@$HOST 'echo' 2>&1 )
                    OUTPUT=$( sshpass -p $PASSWORD ssh -q -o StrictHostKeyChecking=no -p $PORT $USERNAME@$HOST 'echo' 2>&1 )
                    RESULT=$?;
                
                    if [ $RESULT -eq 0 ]; then
                        
                        echo '+++ PASSWORD FINDED IN BASE PASSWORD';
                        echo '+++ SSH-KEY COPIED TO HOST';
    
                        sshpass -p $PASSWORD ssh-copy-id -i $SSH_KEY_PUBLIC -p $PORT $USERNAME@$HOST 
    
                        MATCH_LINE=$(cat $LIST_HOSTNAMES | grep "$HOST:$PORT")
    
                        if [ -z $MATCH_LINE ]; then
       
                            echo "$HOST:$PORT:KEY" >> $LIST_HOSTNAMES;
    
                        elif [ "$MATCH_LINE" = "$HOST:$PORT" ]; then
    
                            sed -i "s/$HOST:$PORT/$HOST:$PORT:KEY/" $LIST_HOSTNAMES;
       
                        fi
    
                        (( STAGE=2 ));
                        break;
            
    
                    ### Change Password If It Expired
    
                    elif [ ! $RESULT -eq 0 ] && [[ $OUTPUT =~ .*password.*expired.* ]]; then
                        echo $OUTPUT; 
                        echo "!!! PASSWORD FINDED BUT IT EXPIRED";
                        echo ">>> TRYING INSTALL NEW PASSWORD";
                        
                        PASSWORD_NEW=${PASSWORD_ARRAY[1]}; 
    
                        if [ $PASSWORD_NEW = $PASSWORD ]; then
    
                            echo "--- OLD PASSWORD == NEW PASSWORD"
                            echo "!!! ADD NEW PASSWORD IN BASE PASSWORD LIST!!!"
                            exit 0;
                        
                        else
    
                            /bin/expect -c '
                                spawn -noecho /bin/ssh -q -o StrictHostKeychecking=no '$USERNAME'@'$HOST'
                                expect "assword: "
                                send "'$PASSWORD'\r"
                                expect {
                                    -timeout 30
                                    -re "\\(current\\) UNIX password:|Current password:|Old password:" {
                                        # Password has expired
                                        send "'$PASSWORD'\r"
                                        expect {
                                            "New password: " {
                                                send "'$PASSWORD_NEW'\r"
                                                exp_continue
                                            }
                                            -re "Retype new password:|new password again:|UNIX password:" {
                                                send "'$PASSWORD_NEW'\r"
                                                exp_continue
                                            }
                                            -re "updated successfully." {
                                                # Password has been changed
                                            }
                                            default {
                                                error "Failed to change the password"
                                            }
                                        }
                                    }
                                }
                            ';
                        fi
                        (( CHANGE_EXP_PASS_TRIG=1 ));
                        break;
    
                    else
        
                        if [ $COUNT_PASS_CHECK -lt 1 ]; then
        
                            echo "--- NOT MATCHING PASSWORDS";
                            (( STAGE=4 ));
                            break;
    
                        fi
            
            
                    fi
                
                    done
                
                fi
                
                if [ $STAGE = 4 ]; then
    
                    ### Exit From Cicle If Nothing Is Done
                    break;
    
                fi
            
            (( COUNT++ ));

            if [ $COUNT -gt 4 ]; then

                echo "!!! ERROR: TOO MANY ITERATIONS !!!";
                break;

            fi

        done

    done

    ;;


    ### Option Help
    '-h' | '--help' | 'help' )

    echo -e "Usage: $0 <option> <hostname>|<hosts-list> <command>
            \rOptions:
            \r\t-c, --connect, conn     Connect to host
            \r\t-h, --help, help        This help"

    ;;


    ### Option Any Arguments
    *)

    echo -e "!!! Not Matched Option. Try $0 --help for right usage"

    ;;


esac
exit 0
