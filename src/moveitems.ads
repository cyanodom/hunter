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

package MoveItems is

   -- ****f* MoveItems/MoveData
   -- FUNCTION
   -- Move selected files/directories to new place
   -- PARAMETERS
   -- Object - GtkAda Builder used to create UI
   -- SOURCE
   procedure MoveData(Object: access Gtkada_Builder_Record'Class);
   -- ****
   -- ****f* MoveItems/MoveSelected
   -- FUNCTION
   -- Move selected files and directories
   -- PARAMETERS
   -- Overwrite - If True, overwrite existing file or directory, otherwise
   --             ask for overwrite permission. Value is set to False if
   --             permission was only for one file or directory
   -- SOURCE
   procedure MoveSelected(Overwrite: in out Boolean);
   -- ****
   -- ****f* CopyItems/SkipCopying
   -- FUNCTION
   -- Skip moving current file and move to next
   -- SOURCE
   procedure SkipMoving;
   -- ****

end MoveItems;
