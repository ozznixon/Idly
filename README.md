# Idly
Asynchronous Socket for Free Pascal (Mac OSX, Linux, Windows, and more)

## Core Architecture Concept
Idly relies on an explicit architectural separation:

   1. The Core Engine (TIdlyEngine): Handles low-level network I/O, socket state management, and connection events using an event loop or epoll/kqueue abstraction.
   2. The RFC Handlers (IIdlyProtocolHandler): Plug-and-play modules that implement specific RFC specifications (e.g., RFC 7230 for HTTP, RFC 5321 for SMTP).

------------------------------
## Phase 1: The Base Contract (Idly.Types.pas)
This unit defines the interface that all future RFC handlers must implement. This ensures total decoupling.

## Phase 2: The Network Engine (Idly.Core.pas)
A lightweight, non-blocking engine wrapper. To add an RFC to your application, you simply register its handler to a port.
* The Core Multi-Protocol Loop Structure
The infrastructure relies on managing a master socket descriptor set (TFDSet). The loop monitors all listening servers and active client connections simultaneously inside a non-blocking execution cycle.

## Phase 3: Implementing an RFC Example (Idly.RFC865.pas)
To prove scalability, here is a mock implementation of RFC 865 (Quote of the Day Protocol) using the Idly pattern.

## How to Bootstrap Your Framework
To execute and expand Idly, orchestrate the components inside a clean console driver file.
