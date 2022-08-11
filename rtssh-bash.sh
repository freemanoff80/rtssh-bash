#!/bin/bash

USERNAME=testuser

OPTION=$1

SSH_KEY_PRIVAT='/home/mobaxterm/.ssh/id_rsa_all_01'
SSH_KEY_PUBLIC='/home/mobaxterm/.ssh/id_rsa_all_01.pub'

BASE_DIR=./base-lists
LIST_HOSTNAMES=$BASE_DIR/.list-hostnames


if [ ! -f $LIST_HOSTNAMES ]; then
    touch $LIST_HOSTNAMES
fi

PORTS_ARRAY=(
30012
22
)


case "$OPTION" in

    # Option for connection to host
    '-c' | '--connect' | 'conn' )

    if [ -z $2 ]; then
        echo '--- HOST NOT SPECIFIED';
        exit 1;
    else
        HOST=$2;
        echo ">>> CONNECT TO $HOST";
    fi
    
    # Check Hostname in Base List
    HOST_PORT=$(grep $HOST $LIST_HOSTNAMES)

    if [ -z $HOST_PORT ]; then
        
        echo -e "--- NOT HOSTNAME IN BASE LIST\n??? CHECK CONNECT"

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
                    break;

                else
                    
                    if [ $COUNT -lt 1 ]; then
                        
                        echo "--- NOT CONNECT";
                        echo $OUTPUT;
                        exit 0;
                    
                    fi
                
                fi
            done

    else
        
        echo -e "+++ HOSTNAME EXIST IN BASE LIST"
        HOST=$(echo $HOST_PORT|cut -d ":" -f 1 );
        PORT=$(echo $HOST_PORT|cut -d ":" -f 2 );

    fi

    COUNT=0
    while [ $COUNT -lt 2 ];
        do
        (( COUNT++ ));
    
        # Check SSH Connect by ssh-key
        echo '>>> CHECK SSH CONNECT BY SSH-KEY'
        OUTPUT=$( ssh -q -o BatchMode=yes -o StrictHostKeyChecking=no -i $SSH_KEY_PRIVAT -p $PORT $USERNAME@$HOST 'echo' 2>&1 )
        RESULT=$?;
    
        if [ $RESULT -eq 0 ]; then
            echo '+++ CONNECTED BY SSH-KEY';
            ssh -i $SSH_KEY_PRIVAT -p $PORT $USERNAME@$HOST 
            exit 0;
        else

            echo '--- NOT CONNECT BY SSH-KEY';
    
            # Check Password SSH connection
            echo '>>> CHECK SSH CONNECT BY PASSWORD'
        
            PASSWORD_ARRAY=($(gpg -d -q $BASE_DIR/.list-passwords.gpg))
        
            if [ ${#PASSWORD_ARRAY[*]} -eq 0 ]; then
                echo "!!! PASSWORD LIST IS EMPTY";
                exit 0;
            fi
            
            COUNT_PASS_CHECK=${#PASSWORD_ARRAY[*]};
        
            for PASSWORD in ${PASSWORD_ARRAY[*]};
                do

                echo -ne ">>> TRYING PASSWORD $COUNT_PASS_CHECK\r";

                (( COUNT_PASS_CHECK-- ));
            
                OUTPUT=$( sshpass -p $PASSWORD ssh -o StrictHostKeyChecking=no -p $PORT $USERNAME@$HOST 'echo' 2>&1 )
                RESULT=$?;
            
                if [ $RESULT -eq 0 ]; then
                    
                    echo '+++ PASSWORD FINDED IN BASE PASSWORD';
                    echo '+++ SSH-KEY COPIED TO HOST';
                    sshpass -p $PASSWORD ssh-copy-id -i $SSH_KEY_PRIVAT -p $PORT $USERNAME@$HOST 
                    #exit 0;
                    break;
        
                #else
 
                #echo $OUTPUT;

                # Change Password If It Expired
                #if [[ $OUTPUT =~ .*password.*expired.* ]]; then
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
                                -re "\\(current\\) UNIX password:|Current password:" {
                                    # Password has expired
                                    send "'$PASSWORD'\r"
                                    expect {
                                        "New password: " {
                                            send "'$PASSWORD_NEW'\r"
                                            exp_continue
                                        }
                                        "Retype new password: " {
                                            send "'$PASSWORD_NEW'\r"
                                            exp_continue
                                        }
                                        "all authentication tokens updated successfully." {
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
                #fi

                else
    
                    if [ $COUNT_PASS_CHECK -lt 1 ]; then
    
                        echo "--- NOT MATCHING PASSWORDS";
                        exit 0; 
                    fi
        
        
                fi
            
                done
            
            fi
        done

    ;;


    test)

    # Check Password SSH connection

    PASSWORD_ARRAY=($(gpg -d -q $BASE_DIR/.list-passwords.gpg))
    
    if [ ${#PASSWORD_ARRAY[*]} -eq 0 ]; then
        echo "!!! Password List Is Empty";
    else

        for PASSWORD in ${PASSWORD_ARRAY[*]};
            do
        
            STATUS=$(sshpass -p $PASSWORD ssh -o StrictHostKeyChecking=no $USERNAME@$HOSTNAME 'echo' &>/dev/null;echo $?)
        
            if [ $STATUS -eq 0 ]; then
                echo TRUE;
                sshpass -p $PASSWORD ssh -o StrictHostKeyChecking=no $USERNAME@$HOSTNAME
            else
                echo FALSE;
            fi
        
            done

    fi

    ;;


    # Option Help
    '-h' | '--help' | 'help' )

    echo -e "Usage: $0 <option> <hostname>
            \rOptions:
            \r\t-c, --connect, conn     Connect to host
            \r\t-h, --help, help        This help"

    ;;


    # Option Any Arguments
    *)

    echo -e "!!! Not Matched Option. Try $0 --help for right usage"

    ;;


esac
exit 0
