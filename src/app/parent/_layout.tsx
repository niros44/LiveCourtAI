import { Tabs } from 'expo-router';

import { sharedTabsScreenOptions, tabIcon } from '@/components/navigation/tabBarOptions';

export default function ParentTabsLayout() {
  return (
    <Tabs screenOptions={sharedTabsScreenOptions}>
      <Tabs.Screen name="index" options={{ title: 'Home', ...tabIcon('home-outline') }} />
      <Tabs.Screen name="admin" options={{ title: 'Transactions', ...tabIcon('card-outline') }} />
      <Tabs.Screen name="carpool" options={{ title: 'Carpool', ...tabIcon('car-outline') }} />
      <Tabs.Screen name="events" options={{ title: 'Events', ...tabIcon('calendar-outline') }} />
    </Tabs>
  );
}
