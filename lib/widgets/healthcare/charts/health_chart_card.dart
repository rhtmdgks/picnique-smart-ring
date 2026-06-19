/// Healthcare chart shell — replaces legacy RealTimeGraphCard naming.
library;

export '../real_time_graph_card.dart'
    show RealTimeGraphCard, showActivityCalendarSheet, SleepStackBar;

import '../real_time_graph_card.dart';

typedef HealthChartCard = RealTimeGraphCard;
