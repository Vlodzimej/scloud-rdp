/**
 * Copyright (C) 2021- Morpheusly Inc. All rights reserved.
 *
 * This is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * (at your option) any later version.
 *
 * This software is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this software; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307,
 * USA.
 */

import Foundation

class Constants {
    class var UNSELECTED_SETTINGS_ID: String { return "unselected" }
    class var DEFAULT_SETTINGS_ID: String { return "default" }
    class var CURRENT_CONNECTIONS_VERSION: Int { return 2 }
    class var DEFAULT_CONNECTIONS_VERSION: Int { return 1 }
    class var SAVED_CONNECTIONS_VERSION_KEY: String { return "connections_version" }
    class var SAVED_CONNECTIONS_KEY: String { return "connections" }
    class var SAVED_DEFAULT_SETTINGS_KEY: String { return "defaults" }
    class var DEFAULT_LAYOUT: String { return "English (US)" }
    class var LAYOUT_PATH: String { return "aSPICE-resources/Resources/layouts/" }
    class var MAX_RESOLUTION_FOR_AUTO_SCALE_UP_IOS: Double { return 2000.0 }
    class var MIN_RESOLUTION_SCALE_UP_FACTOR: Double { return 1.5 }
    class var SCROLL_TOLERANCE: Double { return 1.2 }
    class var DEFAULT_BUNDLE_ID: String { return "com.iiordanov.sCloudRDP" }
    class var DEFAULT_DESKTOP_SCALE_FACTOR: Int { return 100 }
    class var SCALE_FACTOR_ENTRIES: Array<Int> { return Array(stride(from: 100, to: 500, by: 10)) }
    class var CUSTOM_RESOLUTION_ENTRIES: Array<Int> { return Array(stride(from: 128, to: 4097, by: 128)) }
    class var DEFAULT_WIDTH: Int { return 1280 }
    class var DEFAULT_HEIGHT: Int { return 768 }
}

