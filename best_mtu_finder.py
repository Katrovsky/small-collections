import subprocess
import platform
import sys

def ping(host: str, packet_size: int, df_flag: bool = True) -> bool:
    try:
        if platform.system().lower() == "windows":
            args = ["ping", "-n", "1", "-l", str(packet_size)]
            if df_flag:
                args.append("-f")
        else:
            args = ["ping", "-c", "1", "-s", str(packet_size)]
            if df_flag:
                args.extend(["-M", "do"])
        
        args.append(host)
        result = subprocess.run(args, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        return result.returncode == 0
    except Exception:
        return False

def find_mtu_exact(host: str, start: int = 1500) -> int:
    low, high = 1, start
    last_success = 0

    print("Starting MTU search...")

    while low <= high:
        mid = (low + high) // 2
        print(f"Testing packet size: {mid} bytes...")
        
        if ping(host, mid, True):
            last_success = mid
            low = mid + 1
        else:
            high = mid - 1
    
    return last_success

def test_stability(host: str, size: int, tests: int = 10) -> float:
    successes = 0
    print(f"\nTesting stability for {size} bytes packet size...")
    
    for i in range(tests):
        print(f"Test {i+1}/{tests}...")
        if ping(host, size, True):
            successes += 1
    
    return successes / tests

def main():
    host = "www.google.com"
    
    print(f"Checking connection to {host}...")
    if not ping(host, 32, False):
        print(f"Cannot reach {host}. Please check your internet connection.")
        return
    
    optimal_size = find_mtu_exact(host)
    stability = test_stability(host, optimal_size)
    
    print("="*50)
    print(f"Optimal packet size: {optimal_size}")
    print(f"Recommended MTU: {optimal_size + 28}")
    print(f"Stability: {stability*100:.1f}%")
    print("="*50)
    
    print("\nTo apply the changes:")
    print(f"1. Go to your router's settings")
    print(f"2. Set MTU = {optimal_size + 28}")
    print(f"3. Save and reboot the router")
    
    print("\nPress Enter to exit...")
    input()

if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\nOperation interrupted.")
        sys.exit(1)
