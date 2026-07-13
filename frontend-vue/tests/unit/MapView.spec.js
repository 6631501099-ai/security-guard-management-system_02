import { shallowMount } from '@vue/test-utils'
import MapView from '@/projects/views/map/MapView.vue'

describe('MapView', () => {
  it('normalizes account GPS data into map locations', () => {
    const wrapper = shallowMount(MapView)

    const account = {
      _id: 'abc123',
      name: 'Test Guard',
      email: 'guard@example.com',
      address: [{ gps: { latitude: 13.7563, longitude: 100.5018 } }],
      updatedAt: '2024-01-01T00:00:00.000Z'
    }

    const normalized = wrapper.vm.normalizeAccountLocation(account)

    expect(normalized).toEqual(expect.objectContaining({
      _id: 'abc123',
      name: 'Test Guard',
      email: 'guard@example.com',
      lat: 13.7563,
      lng: 100.5018
    }))
    expect(normalized.lastUpdate).toBeGreaterThan(0)
  })

  it('returns null when GPS data is missing', () => {
    const wrapper = shallowMount(MapView)
    const normalized = wrapper.vm.normalizeAccountLocation({ _id: 'x', email: 'guard@example.com' })
    expect(normalized).toBeNull()
  })

  it('normalizes ProjectEND Firestore location documents into map locations', () => {
    const wrapper = shallowMount(MapView)
    const documentSnapshot = {
      id: 'user-123',
      data: () => ({
        name: 'Mobile Guard',
        email: 'mobile@example.com',
        lat: 14.1234,
        lng: 100.5678,
        isActive: true,
        outOfScope: false,
        lastUpdate: { seconds: 1710000000, nanoseconds: 0 }
      })
    }

    const normalized = wrapper.vm.normalizeProjectEndLocation(documentSnapshot)

    expect(normalized).toEqual(expect.objectContaining({
      _id: 'user-123',
      name: 'Mobile Guard',
      email: 'mobile@example.com',
      lat: 14.1234,
      lng: 100.5678
    }))
    expect(normalized.lastUpdate).toBeGreaterThan(0)
  })
})
