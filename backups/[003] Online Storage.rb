#===============================================================================
# Global Battle Agency / Online Trading
#===============================================================================

module GlobalBattleAgency
  API_URL = "https://global-battle-agency.kirbywithaz.workers.dev"

  #=============================================================================
  # Configuration
  #=============================================================================
  STUDIO_NAME   = "KirbywithaZ_Games"
  SHARED_FOLDER = ENV['AppData'] + "/#{STUDIO_NAME}/"

  #=============================================================================
  # Principles
  #=============================================================================

  # Returns a unique master key for the current player
  def self.get_master_key
    return "#{$player.name}_#{$player.id}"
  end

  # Creates the "Business Card" for cross-game recognition
  def self.save_identity_locally
    begin
      Dir.mkdir(SHARED_FOLDER) if !File.exists?(SHARED_FOLDER)
      File.open(SHARED_FOLDER + "gba_identity.txt", "w") { |f| 
        f.write(self.get_master_key) 
      }
      echoln "GBA: Identity linked locally."
    rescue
      echoln "GBA: Failed to save local identity."
    end
  end

  #=============================================================================
  # Cloud Storage
  #=============================================================================

  # Uploads a Pokémon to the cloud and removes it from the party
  def self.upload_pokemon(slot = 0)
    pkmn = $player.party[slot]
    return pbMessage(_INTL("No Pokemon found in slot {1}!", slot + 1)) if !pkmn
    return pbMessage(_INTL("You can't deposit your last Pokemon!")) if $player.party.length <= 1

    pokemon_dna = [Marshal.dump(pkmn)].pack("m0")
    payload = { "id" => self.get_master_key, "data" => pokemon_dna }

    pbMessage(_INTL("Sending {1} to the GBA cloud...", pkmn.name))

    begin
      response = HTTPLite.post("#{API_URL}/save", payload)
      if response[:body] && response[:body].include?("OK")
        $player.party.delete_at(slot)
        
        # Automatically save identity on success so other games can find this
        self.save_identity_locally 
        
        pbMessage(_INTL("Success! {1} has been moved to the cloud.", pkmn.name))
      else
        pbMessage(_INTL("The cloud is full! Try again later."))
      end
    rescue Exception => e
      echoln "GBA Error: #{e.message}"
      pbMessage(_INTL("Failed to connect to the GBA cloud."))
    end
  end

  # Downloads a Pokémon from the cloud
  def self.download_pokemon
    if $player.party_full?
      return pbMessage(_INTL("Your party is full! Make some room first."))
    end
    
    pbMessage(_INTL("Accessing the GBA cloud..."))
    id = self.get_master_key
    
    self.fetch_and_load(id)
  end

  #=============================================================================
  # Reunion System
  #=============================================================================

  # Automatically finds a Pokémon from a previous game.
  def self.auto_invite_reunion
    if $player.party_full?
      return pbMessage(_INTL("Your party is full!"))
    end

    path = SHARED_FOLDER + "gba_identity.txt"
    if File.exists?(path)
      reunion_id = File.read(path).strip
      pbMessage(_INTL("A past journey was detected! Searching for companions..."))
      self.fetch_and_load(reunion_id)
    else
      pbMessage(_INTL("No records of a past journey found on this PC."))
    end
  end

  #=============================================================================
  # Data Handling
  #=============================================================================

  # Handles communication with the server to fetch and load Pokémon data
  def self.fetch_and_load(target_id)
    begin
      response = HTTPLite.get("#{API_URL}/get?id=#{target_id}")
      data = response[:body]

      if data && data != "NOT_FOUND" && !data.include?("Error")
        decoded_data = data.unpack("m0")[0]
        pkmn = Marshal.load(decoded_data)
        $player.party.push(pkmn)
        
        # Clean up the cloud after a successful transfer
        HTTPLite.get("#{API_URL}/delete?id=#{target_id}")
        
        pbMessage(_INTL("Welcome back, {1}!", pkmn.name))
      else
        pbMessage(_INTL("No Pokemon were found in that cloud locker."))
      end
    rescue Exception => e
      echoln "GBA Error: #{e.message}"
      pbMessage(_INTL("Connection failed! Check your internet."))
    end
  end

end

