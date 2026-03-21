package main

import (
	"encoding/base64"
)

// XOR noise key — same as Python _A
var _xk = []byte{
	0x4f, 0x71, 0x23, 0x98, 0x5c, 0x11, 0xae, 0x77,
	0x3d, 0xe2, 0x09, 0xb4, 0x66, 0x2f, 0x81, 0xc5,
}

func xorDecode(enc string) string {
	raw, err := base64.StdEncoding.DecodeString(enc)
	if err != nil {
		return ""
	}
	out := make([]byte, len(raw))
	for i, b := range raw {
		out[i] = b ^ _xk[i%len(_xk)]
	}
	return string(out)
}

// Access key — _B + _C + _D split
var _p1 = "NT8RxzMnzxJYl03B"
var _p2 = "VEnGvA5ccNMQdJ8f"
var _p3 = "V5g78jYasKMsFWrIOF7tL1m4RA=="

func accessKey() string { return xorDecode(_p1 + _p2 + _p3) }

// API endpoint — _F
var _q1 = "JwVX6C8rgVhckmCaE0HytSMQUPBycsEa"

func apiEndpoint() string { return xorDecode(_q1) }
