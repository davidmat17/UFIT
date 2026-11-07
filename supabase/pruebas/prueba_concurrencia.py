"""Prueba de concurrencia de UFIT (RNF12).

Cien personas piden al mismo tiempo la misma franja, a la que solo le
quedan 5 de sus 75 cupos. Cada petición va por la API REST (PostgREST),
con el token de una persona distinta, igual que desde la aplicación.

Se espera que exactamente 5 reciban "creada", que las otras 95 reciban
"sin_cupo" y que la franja termine con 75 reservas, ni una más.

Uso: python prueba_concurrencia.py <url_api> <secreto_jwt> <franja_id>
"""
import base64, hashlib, hmac, json, sys, threading, time, urllib.request
from collections import Counter

URL, SECRETO, FRANJA = sys.argv[1], sys.argv[2].encode(), int(sys.argv[3])
PERSONAS = 100


def b64(datos: bytes) -> str:
    return base64.urlsafe_b64encode(datos).rstrip(b"=").decode()


def token(sub: str) -> str:
    cabecera = b64(json.dumps({"alg": "HS256", "typ": "JWT"}).encode())
    carga = b64(json.dumps({"sub": sub, "role": "authenticated"}).encode())
    firma = b64(hmac.new(SECRETO, f"{cabecera}.{carga}".encode(), hashlib.sha256).digest())
    return f"{cabecera}.{carga}.{firma}"


salida = threading.Barrier(PERSONAS)
resultados, tiempos = [], []
candado = threading.Lock()


def reservar(i: int) -> None:
    sub = f"00000000-0000-0000-0002-{i:012d}"
    peticion = urllib.request.Request(
        f"{URL}/rpc/reservar_cupos",
        data=json.dumps({"p_franjas": [FRANJA], "p_zona_id": 1}).encode(),
        headers={"Authorization": f"Bearer {token(sub)}", "Content-Type": "application/json"},
    )
    salida.wait()  # todas salen al mismo tiempo
    inicio = time.perf_counter()
    with urllib.request.urlopen(peticion) as r:
        respuesta = json.load(r)
    duracion = time.perf_counter() - inicio
    with candado:
        resultados.append(respuesta[0]["resultado"])
        tiempos.append(duracion)


hilos = [threading.Thread(target=reservar, args=(i,)) for i in range(1, PERSONAS + 1)]
for h in hilos:
    h.start()
for h in hilos:
    h.join()

conteo = Counter(resultados)
tiempos.sort()
print(f"Peticiones simultáneas: {PERSONAS}")
for resultado, n in sorted(conteo.items()):
    print(f"  {resultado}: {n}")
print(f"Tiempo de respuesta: mediana {tiempos[len(tiempos)//2]*1000:.0f} ms, "
      f"máximo {tiempos[-1]*1000:.0f} ms")
