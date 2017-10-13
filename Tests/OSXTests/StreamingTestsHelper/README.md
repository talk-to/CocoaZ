The provided zlib-server.jar can create a server which can be used to do streaming tests.

API
---

* Compress:

```
/compress
POST request

Data: JSON
{"id": <string>, "data": <UTF-8 string to compress>}

Response:
{"data": <base64 encoded compressed data as UTF-8 string>}
```

* Decompress:

```
/decompress
POST request

Data: JSON
{"id": <string>, "data":<base64 encoded compressed data as UTF-8 string>}

Response: JSON
{"data":  <UTF-8 string that was decompressed>}
```

#### Note
The key `id` represents a deflate session where compression/decompression is done by the same deflate/inflate instance for a given `id`. This helps in writing tests mocking the compression/decompression behaviour expected on a stream.

Usage
---

To run this server,

```sh
java -jar Tests/OSXTests/StreamingTestsHelper/zlib-server.jar <port-number>
```

#### Note
You should have jvm installed on your machine to run this.
