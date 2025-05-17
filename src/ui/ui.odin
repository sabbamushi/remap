package ui

import "../domain"

Resolution :: struct {
	width, height: u16,
}

Coordinate :: struct {
	x, y: i16,
}

Player :: struct {
	coordinate: Coordinate,
	resolution: Resolution,
}
