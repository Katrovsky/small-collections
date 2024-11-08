import urllib.request
import json
import socket
import time
from concurrent.futures import ThreadPoolExecutor
from statistics import mean
from functools import lru_cache

@lru_cache(maxsize=1)
def get_twitch_servers():
    with urllib.request.urlopen("https://ingest.twitch.tv/ingests", timeout=5) as response:
        return json.loads(response.read())['ingests']

def test_latency(hostname, timeout=1):
    try:
        start = time.time()
        socket.create_connection((hostname, 443), timeout=timeout).close()
        return (time.time() - start) * 1000
    except (socket.error, socket.timeout):
        return float('inf')

def test_server_quick(server):
    hostname = server['url_template'].split('://')[1].split('/')[0]
    latency = test_latency(hostname)
    return (server, latency) if latency != float('inf') else None

def test_server_detailed(server):
    hostname = server['url_template'].split('://')[1].split('/')[0]
    results = []
    failures = 0
    
    for _ in range(3):
        latency = test_latency(hostname, timeout=2)
        if latency != float('inf'):
            results.append(latency)
        else:
            failures += 1
            if failures > 1:
                break
    
    if not results:
        return {
            'name': server['name'],
            'latency': float('inf'),
            'stability': 0,
            'status': 'недоступен'
        }
    
    avg_latency = mean(results)
    stability = 100 - (max(results) - min(results)) / avg_latency * 100 if len(results) > 1 else 100
    
    return {
        'name': server['name'],
        'latency': round(avg_latency, 1),
        'stability': round(stability, 1),
        'status': 'доступен'
    }

def format_results(results):
    def get_priority(server):
        if server['status'] == 'недоступен':
            return (3, 0, server['latency'])
        elif server['stability'] > 90 and server['latency'] < 100:
            return (0, -server['stability'], server['latency'])
        elif server['stability'] > 75 and server['latency'] < 100:
            return (1, -server['stability'], server['latency'])
        return (2, -server['stability'], server['latency'])
    
    results.sort(key=get_priority)
    
    output = [
        "\nРезультаты тестирования серверов Twitch:\n",
        f"{'Сервер':<35} {'Задержка (мс)':<15} {'Стабильность %':<15} {'Статус'}",
        "-" * 80
    ]
    
    for r in results:
        if r['status'] == 'доступен':
            output.append(f"{r['name']:<35} {r['latency']:<15.1f} {r['stability']:<15.1f} {r['status']}")
        else:
            output.append(f"{r['name']:<35} {'---':<15} {'---':<15} {r['status']}")
    
    return "\n".join(output)

def main():
    try:
        print("Получение списка серверов...", end='', flush=True)
        servers = get_twitch_servers()
        print(" Готово")
        
        print("Быстрая проверка всех серверов...", end='', flush=True)
        with ThreadPoolExecutor(max_workers=20) as executor:
            quick_results = list(filter(None, executor.map(test_server_quick, servers)))
        print(f" Найдено {len(quick_results)} доступных серверов")
        
        quick_results.sort(key=lambda x: x[1])
        closest_servers = [server for server, _ in quick_results[:10]]
        
        print("Подробное тестирование ближайших серверов...", end='', flush=True)
        with ThreadPoolExecutor(max_workers=10) as executor:
            detailed_results = list(executor.map(test_server_detailed, closest_servers))
        print(" Готово\n")
        
        print(format_results(detailed_results))
        
    except Exception as e:
        print(f"\nОшибка: {str(e)}")

if __name__ == "__main__":
    main()