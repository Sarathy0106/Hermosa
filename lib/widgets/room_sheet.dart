import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../services/room_service.dart';
import '../services/theme_provider.dart';
import '../theme.dart';
import 'glass.dart';

class RoomSheet extends StatefulWidget {
  const RoomSheet({super.key});

  @override
  State<RoomSheet> createState() => _RoomSheetState();
}

class _RoomSheetState extends State<RoomSheet> {
  final _codeCtrl = TextEditingController();
  final _serverCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final room = context.read<RoomService>();
      _serverCtrl.text = room.serverUrl;
      if (room.state == RoomConnectionState.disconnected) {
        room.connect();
      }
    });
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _serverCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final room = context.watch<RoomService>();
    final h = context.hermosa;

    if (room.inRoom) {
      return _RoomInfo(room: room);
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: h.textSecondary.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text('Listen Together', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 4),
            Text('Create a room or join one with a code',
                style: TextStyle(color: h.textSecondary, fontSize: 14)),
            const SizedBox(height: 24),

            // Server URL
            TextField(
              controller: _serverCtrl,
              decoration: InputDecoration(
                hintText: 'wss://your-server.com',
                labelText: 'Server URL',
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: h.surfaceHigh,
                suffixIcon: room.state == RoomConnectionState.connected
                    ? const Icon(Icons.check_circle_rounded, color: Colors.green, size: 20)
                    : null,
              ),
              onChanged: (v) {
                if (v.trim().isNotEmpty) room.setServer(v.trim());
              },
            ),
            const SizedBox(height: 16),

            if (room.state == RoomConnectionState.disconnected ||
                room.state == RoomConnectionState.error)
              FilledButton.icon(
                onPressed: () {
                  final url = _serverCtrl.text.trim();
                  if (url.isEmpty) return;
                  room.connect(url);
                },
                icon: const Icon(Icons.link_rounded, size: 20),
                label: const Text('Connect'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),

            if (room.state == RoomConnectionState.connecting)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                    SizedBox(width: 12),
                    Text('Connecting…'),
                  ],
                ),
              ),

            if (room.state == RoomConnectionState.connected &&
                !room.inRoom) ...[
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: room.createRoom,
                      icon: const Icon(Icons.add_rounded, size: 20),
                      label: const Text('Create Room'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 48),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: () => _joinRoom(room),
                      icon: const Icon(Icons.login_rounded, size: 20),
                      label: const Text('Join Room'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 48),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _codeCtrl,
                      textCapitalization: TextCapitalization.characters,
                      decoration: InputDecoration(
                        hintText: 'ROOMCODE',
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: h.surfaceHigh,
                      ),
                      onSubmitted: (_) => _joinRoom(room),
                    ),
                  ),
                  const SizedBox(width: 10),
                  FilledButton(
                    onPressed: () => _joinRoom(room),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Go'),
                  ),
                ],
              ),
            ],

            if (room.error != null && room.state == RoomConnectionState.error)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(room.error!,
                    style: const TextStyle(color: AppColors.danger, fontSize: 13)),
              ),
          ],
        ),
      ),
    );
  }

  void _joinRoom(RoomService room) {
    final code = _codeCtrl.text.trim();
    if (code.isEmpty) return;
    room.joinRoom(code);
  }
}

class _RoomInfo extends StatelessWidget {
  final RoomService room;
  const _RoomInfo({required this.room});

  @override
  Widget build(BuildContext context) {
    final h = context.hermosa;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: h.textSecondary.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Icon(Icons.group_rounded, size: 48, color: h.primary),
            const SizedBox(height: 12),
            Text('Room Active', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                color: h.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(room.roomCode ?? '',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          letterSpacing: 4, fontWeight: FontWeight.w700)),
                  const SizedBox(width: 12),
                  InkWell(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: room.roomCode ?? ''));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Code copied')),
                      );
                    },
                    child: Icon(Icons.copy_rounded, size: 18, color: h.primary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text('${room.members.length} ${room.members.length == 1 ? 'member' : 'members'}',
                style: TextStyle(color: h.textSecondary)),
            const SizedBox(height: 4),
            if (room.isHost)
              Text('You are the host',
                  style: TextStyle(color: h.primary, fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 20),
            if (!room.isHost)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text('Playback is controlled by the host',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              ),
            OutlinedButton.icon(
              onPressed: () {
                room.leaveRoom();
                Navigator.pop(context);
              },
              icon: const Icon(Icons.exit_to_app_rounded, size: 20),
              label: const Text('Leave Room'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.danger,
                side: const BorderSide(color: AppColors.danger),
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void showRoomSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Glass(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      tint: const Color(0xD912121C),
      blur: 28,
      child: ChangeNotifierProvider.value(
        value: context.read<RoomService>(),
        child: const RoomSheet(),
      ),
    ),
  );
}
