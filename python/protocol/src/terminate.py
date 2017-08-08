import signal
import time

def cleanup(signum, frame):
    print('cleaning up')
    raise Exception('cleanup!')

def main():
    signal.signal(signal.SIGINT,  cleanup)
    signal.signal(signal.SIGTERM, cleanup)

    try:
        counter = 0
        while True:
            print('sleeping {}'.format(counter))
            time.sleep(0.05)
            counter += 1
    except Exception as ex:
        print('exception: {}'.format(ex))
    finally:
        print('running finally block')

if __name__ == '__main__':
    main()
