-- Copyright (c) 2019 Bartek thindil Jasicki <thindil@laeran.pl>
--
-- This program is free software: you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation, either version 3 of the License, or
-- (at your option) any later version.
--
-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with this program.  If not, see <http://www.gnu.org/licenses/>.

with Gtkada.Builder; use Gtkada.Builder;

package Bookmarks is

   -- ****f* Bookmarks/GoHome
   -- FUNCTION
   -- Go to user home directory
   -- PARAMETERS
   -- Object - GtkAda Builder used to create UI
   -- SOURCE
   procedure GoHome(Object: access Gtkada_Builder_Record'Class);
   -- ****
   -- ****f* Bookmarks/CreateBookmarkMenu
   -- FUNCTION
   -- Create bookmarks menu - show only existing bookmarks
   -- PARAMETERS
   -- Object - GtkAda Builder used to create UI
   -- SOURCE
   procedure CreateBookmarkMenu(Object: access Gtkada_Builder_Record'Class);
   -- ****

end Bookmarks;