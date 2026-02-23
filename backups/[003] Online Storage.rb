#===============================================================================
# Global Battle Agency (GBA) / Online Storage Module (v21.1)
#===============================================================================
# Author: KirbyWithAz
# Purpose: Handles Pokémon cloud storage, retrieval, and cross-game access
#          via the Reunion System. Includes multi-deposit, cloud upload/download,
#          and local identity tracking.
# Version: 21.1
#===============================================================================

module GlobalBattleAgency
  #===========================================================================
  # Configuration
  #===========================================================================
  API_URL       = "https://global-battle-agency.kirbywithaz.workers.dev"
  STUDIO_NAME   = "KirbyWithAz_Games"
  SHARED_FOLDER = ENV['AppData'] + "/#{STUDIO_NAME}/"
  IDENTITY_FILE = SHARED_FOLDER + "gba_registry.txt"

  #===========================================================================
  # Identity Management
  #===========================================================================

  #---------------------------------------------------------------------------
  # Master Key
  #---------------------------------------------------------------------------
  # Generates a unique master key for the current player
  def self.get_master_key
    "#{$player.name}_#{$player.id}"
  end

  #---------------------------------------------------------------------------
  # Local Identity Storage
  #---------------------------------------------------------------------------
  # Records this save file's ID so other games can find it
  def self.save_identity_locally
    begin
      Dir.mkdir(SHARED_FOLDER) unless File.exists?(SHARED_FOLDER)
      registry = {}
      if File.exists?(IDENTITY_FILE)
        begin
          content = File.read(IDENTITY_FILE)
          registry = eval(content) if content.include?("{")
        rescue
          registry = {}
        end
      end
      registry[System.game_title] = self.get_master_key
      File.open(IDENTITY_FILE, "w") { |f| f.write(registry.inspect) }
    rescue
      echoln "GBA: Failed to save local identity."
    end
  end

  #===========================================================================
  # Reunion System / Cross-Game Access
  #===========================================================================
  
  #---------------------------------------------------------------------------
  # Auto-Invite Legacy
  #---------------------------------------------------------------------------
  # Scans for other game IDs registered in the studio folder
  # Allows players to access past game clouds
  def self.auto_invite_legacy
    if $player.party_full?
      return pbMessage(_INTL("Your party is full!"))
    end

    if File.exists?(IDENTITY_FILE)
      begin
        registry = eval(File.read(IDENTITY_FILE))
        registry.delete(System.game_title) # Skip current game

        if registry.empty?
          return pbMessage(_INTL("No other local game records were found."))
        end

        # Display available past journeys
        commands = registry.keys
        choice = pbMessage(_INTL("Past journeys detected! Which record should be accessed?"), commands, -1)
        
        if choice >= 0
          target_game = commands[choice]
          legacy_id = registry[target_game]
          pbMessage(_INTL("Accessing the cloud for {1}...", target_game))
          self.fetch_and_load(legacy_id)
        end
      rescue Exception => e
        echoln "GBA Reunion Error: #{e.message}"
        pbMessage(_INTL("The identity registry is corrupted."))
      end
    else
      pbMessage(_INTL("No records of a past journey found on this device."))
    end
  end

  #===========================================================================
  # Upload / Deposit Pokémon
  #===========================================================================

  #---------------------------------------------------------------------------
  # Multi-Deposit Logic
  #---------------------------------------------------------------------------
  # Allows the player to select and deposit multiple Pokémon into the cloud
  def self.upload_pokemon
    if $player.party.length <= 1
      return pbMessage(_INTL("You must keep at least one Pokémon in your party!"))
    end

    selected_indices = []

    #-----------------------------------------------------------------------
    # Selection Loop
    #-----------------------------------------------------------------------
    loop do
      break if selected_indices.length >= 5
      break if ($player.party.length - selected_indices.length) <= 1

      msg = selected_indices.empty? ? 
            _INTL("Select a Pokémon to deposit.") : 
            _INTL("{1} selected. Select another or press B to finish.", selected_indices.length)

      pbChoosePokemon(1, 2, proc { |pkmn| !pkmn.egg? })
      idx = pbGet(1)

      if idx < 0
        break if selected_indices.any?
        return
      end

      if selected_indices.include?(idx)
        pbMessage(_INTL("That Pokémon is already selected!"))
      else
        selected_indices.push(idx)
        pbMessage(_INTL("Added to the deposit list.")) if selected_indices.length == 1
      end
    end

    return if selected_indices.empty?

    #-----------------------------------------------------------------------
    # Confirmation Step
    #-----------------------------------------------------------------------
    confirm_msg = selected_indices.length == 1 ? 
                  _INTL("Deposit this Pokémon into the cloud?") : 
                  _INTL("Deposit these {1} Pokémon into the cloud?", selected_indices.length)

    if pbConfirmMessage(confirm_msg)
      pbMessage(_INTL("Connecting to the GBA cloud..."))

      #---------------------------------------------------------------------
      # Serialization & Payload
      #---------------------------------------------------------------------
      sending_party = selected_indices.map { |i| $player.party[i] }
      pokemon_dna = [Marshal.dump(sending_party)].pack("m0")
      payload = { "id" => self.get_master_key, "data" => pokemon_dna }

      #---------------------------------------------------------------------
      # Cloud Upload
      #---------------------------------------------------------------------
      begin
        response = HTTPLite.post("#{API_URL}/save", payload)
        if response[:body]&.include?("OK")
          # Remove deposited Pokémon from party
          selected_indices.sort.reverse_each { |i| $player.party.delete_at(i) }
          self.save_identity_locally

          # Success message
          msg = selected_indices.length == 1 ? 
                _INTL("Success! The Pokémon was moved to the cloud.") : 
                _INTL("Success! The Pokémon were moved to the cloud.")
          pbMessage(msg)
        else
          pbMessage(_INTL("Cloud error. Please try again later."))
        end
      rescue Exception => e
        pbMessage(_INTL("Connection failed!"))
      end
    end
  end

  #===========================================================================
  # Withdrawal & Retrieval
  #===========================================================================

  #---------------------------------------------------------------------------
  # Download Pokémon
  #---------------------------------------------------------------------------
  # Retrieves Pokémon from the cloud and adds them to the player's party
  def self.download_pokemon
    pbMessage(_INTL("Accessing the GBA cloud..."))
    self.fetch_and_load(self.get_master_key)
  end

  #---------------------------------------------------------------------------
  # Fetch & Load Logic
  #---------------------------------------------------------------------------
  # Fetches stored Pokémon from the cloud and loads them into the party
  def self.fetch_and_load(target_id)
    begin
      response = HTTPLite.get("#{API_URL}/get?id=#{target_id}")
      data = response[:body]

      if data && data != "NOT_FOUND" && !data.include?("Error")
        decoded = data.unpack("m0")[0]
        pkmn_data = Marshal.load(decoded)

        new_arrivals = pkmn_data.is_a?(Array) ? pkmn_data : [pkmn_data]
        count = new_arrivals.length

        # Check party capacity
        if ($player.party.length + count) > 6
          return pbMessage(_INTL("Not enough room in the party for {1} Pokémon!", count))
        end

        # Add Pokémon to party
        new_arrivals.each { |p| $player.party.push(p) }

        # Cleanup cloud storage
        HTTPLite.get("#{API_URL}/delete?id=#{target_id}")

        # Success message
        msg = count == 1 ? 
              _INTL("Transfer complete! The Pokémon has returned.") : 
              _INTL("Transfer complete! The Pokémon have returned.")
        pbMessage(msg)
      else
        pbMessage(_INTL("No Pokémon found in that locker."))
      end
    rescue Exception => e
      pbMessage(_INTL("Connection error."))
    end
  end
end
