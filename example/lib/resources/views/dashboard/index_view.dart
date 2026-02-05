import 'package:flutter/material.dart';
import 'package:magic/magic.dart';

import '../../../app/controllers/dashboard_controller.dart';

/// Dashboard Index View.
///
/// Responsive dashboard with breakpoint info.
class DashboardIndexView extends StatelessWidget {
  final DashboardController controller;

  const DashboardIndexView({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [_breakpointBadge(context)],
      ),
      body: controller.renderState((data) => _buildLayout(context, data)),
    );
  }

  Widget _breakpointBadge(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: WDiv(
        className: 'px-3 py-1 bg-blue-500 rounded-full',
        child: WText(
          context.activeBreakpoint.isEmpty ? 'xs' : context.activeBreakpoint,
          className: 'text-white text-xs font-bold',
        ),
      ),
    );
  }

  Widget _buildLayout(BuildContext context, Map<String, dynamic> data) {
    final isDesktop = context.isDesktop;
    final isTablet = context.isTablet;

    return SingleChildScrollView(
      padding: EdgeInsets.all(
        isDesktop
            ? 32
            : isTablet
                ? 24
                : 16,
      ),
      child: WDiv(
        className: 'flex flex-col gap-6',
        children: [
          if (isDesktop)
            _buildDesktopGrid(data)
          else if (isTablet)
            _buildTabletGrid(data)
          else
            _buildPhoneGrid(data),
          _breakpointInfo(context),
        ],
      ),
    );
  }

  Widget _buildPhoneGrid(Map<String, dynamic> data) {
    return WDiv(
      className: 'flex flex-col gap-4',
      children: [
        _infoCard('Total Users', data['totalUsers'], Icons.people),
        _infoCard('Active Users', data['activeUsers'], Icons.person),
        _infoCard('Revenue', '\$${data['revenue']}', Icons.attach_money),
        _infoCard('Orders', data['orders'], Icons.shopping_cart),
      ],
    );
  }

  Widget _buildTabletGrid(Map<String, dynamic> data) {
    return WDiv(
      className: 'flex flex-col gap-4',
      children: [
        WDiv(
          className: 'flex flex-row gap-4',
          children: [
            Expanded(
              child: _infoCard('Total Users', data['totalUsers'], Icons.people),
            ),
            Expanded(
              child: _infoCard(
                'Active Users',
                data['activeUsers'],
                Icons.person,
              ),
            ),
          ],
        ),
        WDiv(
          className: 'flex flex-row gap-4',
          children: [
            Expanded(
              child: _infoCard(
                'Revenue',
                '\$${data['revenue']}',
                Icons.attach_money,
              ),
            ),
            Expanded(
              child: _infoCard('Orders', data['orders'], Icons.shopping_cart),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDesktopGrid(Map<String, dynamic> data) {
    return WDiv(
      className: 'flex flex-row gap-6',
      children: [
        Expanded(
          child: _infoCard('Total Users', data['totalUsers'], Icons.people),
        ),
        Expanded(
          child: _infoCard('Active Users', data['activeUsers'], Icons.person),
        ),
        Expanded(
          child: _infoCard(
            'Revenue',
            '\$${data['revenue']}',
            Icons.attach_money,
          ),
        ),
        Expanded(
          child: _infoCard('Orders', data['orders'], Icons.shopping_cart),
        ),
      ],
    );
  }

  Widget _infoCard(String title, dynamic value, IconData icon) {
    return WDiv(
      className: 'bg-white rounded-xl shadow-md p-6',
      child: WDiv(
        className: 'flex flex-row items-center gap-4',
        children: [
          WDiv(
            className:
                'w-12 h-12 bg-blue-100 rounded-lg flex items-center justify-center',
            child: Icon(icon, color: const Color(0xFF3B82F6)),
          ),
          WDiv(
            className: 'flex flex-col',
            children: [
              WText(title, className: 'text-gray-500 text-sm'),
              WText('$value', className: 'text-xl font-bold text-gray-900'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _breakpointInfo(BuildContext context) {
    final screens = context.windScreens;

    return WDiv(
      className: 'bg-gray-100 rounded-xl p-6 mt-4',
      children: [
        WText(
          'Wind Theme Breakpoints',
          className: 'font-bold text-gray-900 mb-4',
        ),
        WDiv(
          className: 'flex flex-col gap-2',
          children: [
            _breakpointRow(
              'Current Width',
              '${context.screenWidth.toInt()}px',
              active: true,
            ),
            _breakpointRow(
              'Active Breakpoint',
              context.activeBreakpoint.isEmpty
                  ? 'xs'
                  : context.activeBreakpoint,
              active: true,
            ),
            const Divider(),
            ...screens.entries.map(
              (e) => _breakpointRow(e.key, '${e.value}px'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _breakpointRow(String name, String value, {bool active = false}) {
    return WDiv(
      className: 'flex flex-row justify-between py-1',
      children: [
        WText(
          name,
          className: active ? 'font-bold text-blue-500' : 'text-gray-600',
        ),
        WText(
          value,
          className: active ? 'font-bold text-blue-500' : 'text-gray-600',
        ),
      ],
    );
  }
}
