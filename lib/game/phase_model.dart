import 'package:flutter/material.dart';

class Phase {
  const Phase({
    required this.id,
    required this.name,
    required this.description,
    required this.targetScore,
    required this.moves,
    required this.accentColor,
    required this.icon,
    required this.rows,
    required this.cols,
    required this.runeTypes,
  });

  final int id;
  final String name;
  final String description;
  final int targetScore;
  final int moves;
  final Color accentColor;
  final String icon;
  final int rows;
  final int cols;
  final int runeTypes;
}

const List<Phase> kPhases = [
  Phase(
    id: 1,
    name: 'Planície das Runas',
    description: 'O início da jornada arcana.',
    targetScore: 2000,
    moves: 30,
    accentColor: Color(0xFF8B5CF6),
    icon: '✦',
    rows: 6,
    cols: 6,
    runeTypes: 4,
  ),
  Phase(
    id: 2,
    name: 'Floresta do Crepúsculo',
    description: 'Energias antigas despertam.',
    targetScore: 4500,
    moves: 25,
    accentColor: Color(0xFF10B981),
    icon: '⬡',
    rows: 7,
    cols: 7,
    runeTypes: 5,
  ),
  Phase(
    id: 3,
    name: 'Citadela de Cristal',
    description: 'A magia pulsa em cada pedra.',
    targetScore: 8000,
    moves: 22,
    accentColor: Color(0xFF06B6D4),
    icon: '✶',
    rows: 8,
    cols: 8,
    runeTypes: 5,
  ),
  Phase(
    id: 4,
    name: 'Abismo das Estrelas',
    description: 'Onde o céu encontra o caos.',
    targetScore: 14000,
    moves: 20,
    accentColor: Color(0xFFF59E0B),
    icon: '☽',
    rows: 8,
    cols: 8,
    runeTypes: 6,
  ),
  Phase(
    id: 5,
    name: 'Trono do Eterno',
    description: 'O desafio supremo te aguarda.',
    targetScore: 25000,
    moves: 18,
    accentColor: Color(0xFFEF4444),
    icon: '✷',
    rows: 8,
    cols: 8,
    runeTypes: 6,
  ),
];
