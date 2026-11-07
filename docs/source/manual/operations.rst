.. _man-operations:

##########
Operations
##########

.. rubric:: How to run a Dropwizard application in production: what it needs from the machine and the network, the
            limits it has by default, and the settings to review before going live.

Defaults on this page come from the code of this release. See :ref:`man-configuration-all` for every option.

.. _man-operations-requirements:

Requirements
============

Dropwizard 5.0.x needs Java 17 or newer. It is built and tested on Java 17, 21 and 25, on Linux and Windows.
``server.enableVirtualThreads`` needs a JVM with virtual threads, which means Java 21 or newer.

Dropwizard doesn't set a minimum CPU or memory size. What your application needs depends mostly on your own code, so
measure it under realistic load. The measurements below show where the framework's own costs lie, and the limits you
are likely to reach first.

.. _man-operations-measurements:

Measured capacity
=================

These numbers come from the example application in the ``dropwizard-example`` module, serving
``GET /hello-world``, a 37-byte JSON response with no database access. They describe the framework's overhead on one
machine, not what your application will achieve.

* Machine: a KVM virtual machine with 16 vCPUs and 16 GB of memory, running Linux 6.8 and Docker. Other services were
  running on it, so expect some variation.
* JVM: Eclipse Temurin 17.0.20.1, ``-Xmx512m``, default garbage collector choice.
* Load: `wrk <https://github.com/wg/wrk>`_ with 2 threads and keep-alive connections, on separate CPUs from the
  application. 15 seconds of warm-up, then 30 seconds measured. Request logging was turned off.

CPU
---

.. list-table::
   :header-rows: 1

   * - CPUs for the application
     - Requests per second
     - p50
     - p99
   * - 1, as a CPU quota (``docker --cpus=1``)
     - 2,200
     - 9–15 ms
     - 95 ms
   * - 2, as a CPU quota
     - 5,400–6,400
     - 1.7 ms
     - 85 ms
   * - 4, as a CPU quota
     - 22,000–23,000
     - 0.7 ms
     - 65 ms
   * - 2, as dedicated CPUs (``docker --cpuset-cpus``)
     - 13,500–15,600
     - 2.0–2.2 ms
     - 7–11 ms
   * - 4, as dedicated CPUs
     - 29,700
     - 1.1 ms
     - 3.5 ms

**CPU quotas add latency when the application uses its whole allowance.** Under a quota, the kernel paused the
application in every 100 ms scheduling period of the measurement, because it had used up its allowance, which is why p99 stayed between 65 and 95 ms
regardless of the number of CPUs. With the same number of dedicated CPUs, p99 was 3.5 ms. If you run under a CPU quota,
such as a container CPU limit, set it well above normal use, or use dedicated CPUs for latency-sensitive services.

**Give the JVM at least 2 CPUs.** With 1 CPU, the JVM chooses the serial garbage collector instead of G1, startup took
about 9 seconds instead of 3.5 to 5, and throughput was less than half of that with 2 CPUs under the same kind of quota.

Memory
------

* **Resident memory** (RSS) was 220–260 MB at idle with ``-Xmx512m``, and 290–400 MB under load with 32 connections.
* **Smallest heap:** with ``-Xmx16m`` the application didn't start, and with ``-Xmx24m`` it started but served no
  requests, logging ``OutOfMemoryError``. ``-Xmx32m`` worked, with about 100 garbage collections per second under load, which
  dropped to about 9 per second at ``-Xmx64m``. These sizes apply to the example application only. Size the heap from
  your own application's live data.
* **Most of the idle footprint is outside the heap.** With ``-Xmx32m``, RSS was still 178 MB at idle and 225 MB under
  load, for class metadata, compiled code, threads and buffers. As a starting point for a container memory limit, allow
  the heap plus at least 250 MB, plus the costs below, then adjust from what you measure.
* **Busy threads:** with 4,000 concurrent connections, RSS reached 856 MB and the thread pool grew to its maximum of
  1,024 threads. That is about 0.5 MB more for each additional thread, including its connection's buffers.
* **Idle keep-alive connections are cheap:** 10,000 idle connections added about 60 MB, around 6 KB each, and 17
  threads.

Startup
-------

The time from launching the example application to its first ``200`` from ``/healthcheck`` was 3.4–4.0 seconds with
4 CPUs, 4.4–4.9 seconds with 2, and about 9 seconds with 1. It includes starting Hibernate. Set readiness probe delays
and orchestrator timeouts from your own application's measured startup time.

Concurrency
-----------

Each request that is being processed holds a thread from the server's pool, which defaults to ``maxThreads: 1024``.
When more requests are in progress than there are threads, they wait, so latency grows while throughput stays roughly
flat:

.. list-table::
   :header-rows: 1

   * - Concurrent connections (4 dedicated CPUs)
     - Requests per second
     - p50
     - p99
   * - 32
     - 29,700
     - 1.1 ms
     - 3.5 ms
   * - 256
     - 27,600
     - 8.6 ms
     - 43 ms
   * - 1,000
     - 26,700
     - 34 ms
     - 120 ms
   * - 4,000
     - 24,200
     - 152 ms
     - 498 ms

Dropwizard has no limit on the number of connections or on the request rate. If you expect more concurrent requests
than your application can serve in time, limit them in a load balancer or proxy in front of it.

.. _man-operations-network:

Network
=======

Ports
-----

By default the application listens on TCP port 8080 and the admin interface on TCP port 8081, both on all network
interfaces and both over plain HTTP. See :ref:`man-operations-admin` before exposing either.

Bytes on the wire
-----------------

.. list-table::
   :header-rows: 1

   * - Exchange
     - Response size
   * - ``GET /hello-world`` (37-byte JSON body)
     - 212 bytes: 175 bytes of headers and the body
   * - ``POST /hello-world`` returning ``204``
     - 87 bytes of headers
   * - ``GET /metrics`` on the admin port
     - 16,108 bytes, or 2,408 bytes with ``Accept-Encoding: gzip``
   * - ``GET /healthcheck`` on the admin port
     - 245 bytes

For small responses the headers are most of the traffic, so bandwidth grows with the request rate more than with the
payload size. At 29,700 requests per second, these ``GET`` responses add up to about 6 MB/s, or 50 Mbit/s, before
TCP/IP overhead. By default, ``GET`` responses of at least 256 bytes are compressed when the client sends
``Accept-Encoding: gzip``; see :ref:`man-configuration-gzip`.

TLS
---

An :ref:`HTTPS connector <man-configuration-https>` served about 25,000 requests per second with p99 at 4.5 ms, against
29,700 and 3.5 ms over HTTP, on 4 dedicated CPUs. These connections were reused, so the cost of TLS handshakes isn't
included. Clients that open a new connection for each request cost much more, so prefer keep-alive connections, or
terminate TLS in a proxy that keeps connections to the application open.

By default the connector excludes SSL, TLS 1.0 and TLS 1.1, and it rejects requests whose SNI host name doesn't match
the certificate. Clients must therefore connect with a host name that the certificate covers.

Timeouts and limits
-------------------

These are the defaults of the :ref:`HTTP connector <man-configuration-http>`:

.. list-table::
   :header-rows: 1

   * - Setting
     - Default
   * - ``idleTimeout``
     - 30 seconds
   * - ``maxRequestHeaderSize`` and ``maxResponseHeaderSize``
     - 8 KiB
   * - ``inputBufferSize`` and ``outputBufferSize``
     - 8 KiB and 32 KiB
   * - ``minRequestDataPerSecond`` and ``minResponseDataPerSecond``
     - 0, meaning no minimum
   * - ``acceptQueueSize``
     - The operating system's default
   * - Request body size
     - No limit

A load balancer that keeps idle connections to the application open for longer than ``idleTimeout`` can send a request
on a connection that the application is closing at that moment, and the client then gets an error. Make the load
balancer's idle timeout for connections to the application shorter than ``idleTimeout``, or raise ``idleTimeout``.

The HTTP clients that ``dropwizard-client`` builds default to 500 ms for ``timeout``, ``connectionTimeout`` and
``connectionRequestTimeout``, with no retries and at most 1,024 connections. Set these explicitly for calls that cross
regions or wait on slow services.

File descriptors
----------------

Each open connection uses one file descriptor: 10,000 connections added 10,000 descriptors to the 20 the example
application used at idle. Make sure the process's open-file limit (``ulimit -n``) is well above the number of
connections you expect, plus the files and database connections your application uses.

.. _man-operations-admin:

Isolating the admin interface
=============================

The admin interface can run tasks, change log levels, trigger garbage collection, and expose thread dumps, metrics and
health check details. **It has no authentication, and by default it listens on all network interfaces on port
8081.** Never expose it to an untrusted network.

Bind it to loopback or a private interface, and restrict access with a firewall or network policy:

.. code-block:: yaml

    server:
      adminConnectors:
        - type: http
          port: 8081
          bindHost: 127.0.0.1

The :ref:`simple server <man-configuration-simple>` serves the admin interface on the application connector, under
``adminContextPath``. With that server type, anyone who can reach your application can also reach the admin interface
unless a proxy in front of it blocks that path, so prefer the default server type when the port is reachable by
untrusted clients.

.. _man-operations-limits:

Limiting request bodies
=======================

Dropwizard doesn't limit the size of request bodies. If your application accepts requests from untrusted clients,
limit body sizes in a reverse proxy or a servlet filter.

Compressed bodies need particular care. With :ref:`gzip <man-configuration-gzip>` enabled, which is the default,
requests sent with ``Content-Encoding: gzip`` are decompressed with no limit on the decompressed size. In a test, a
request body of about 1 MB that decompresses to 1 GB was accepted with ``204 No Content`` after 3.4 seconds of
processing. A size limit applied before decompression doesn't protect against this. If your clients don't need to send
compressed requests, have your proxy reject them. Setting ``server.gzip.enabled: false`` also stops decompression, but
it turns off response compression too.

Jackson applies its default ``StreamReadConstraints`` to JSON, including limits on nesting depth and string length,
but those defaults don't limit the total size of a document.

.. _man-operations-logging:

Disk and logging
================

The example application's runnable jar is 60 MB; yours depends on its dependencies. Most of the disk space a running
application needs is for logs.

A request log line for a simple ``GET`` was 111 bytes, so 1,000 requests per second write about 9.6 GB a day of request
logs before compression. Use the :ref:`file appender <man-configuration-logging-file>` with ``archive: true`` to rotate
logs, and set ``archivedFileCount`` so that old files are removed.

Request logs include the full query string. Avoid sending secrets in URLs: for example, ``OAuthCredentialAuthFilter``
accepts tokens in the ``access_token`` query parameter, and those tokens then appear in request logs, so clients should
send them in the ``Authorization`` header instead.

.. _man-operations-pools:

Database pools
==============

Database pools default to ``initialSize: 10``, ``minSize: 10`` and ``maxSize: 100``, and a caller waits up to 30
seconds for a connection (``maxWaitForConnection``). The combined ``maxSize`` of all instances of your application must
stay within what your database allows. The pool metrics show whether a limit is being reached.

.. _man-operations-health:

Health checks and metrics
=========================

Use :ref:`man-core-health` for readiness and liveness checks, because it can be served to load balancers on the
application port. The admin ``/healthcheck`` endpoint includes error messages and stack traces when a check fails,
which is another reason to keep the admin port private.

Configure :ref:`reporters <man-configuration-metrics>` to export metrics to your monitoring system.

.. _man-operations-shutdown:

Graceful shutdown
=================

``shutdownGracePeriod`` (30 seconds by default) is the maximum time to wait for Jetty and ``Managed`` objects to stop.
Set your orchestrator's termination timeout higher than this value, so that the process isn't stopped while it is still
shutting down.

.. _man-operations-not-measured:

What wasn't measured
====================

HTTP/2, TLS handshakes, large request or response bodies, endpoints that use a database, ARM processors and Windows
weren't part of these measurements.
